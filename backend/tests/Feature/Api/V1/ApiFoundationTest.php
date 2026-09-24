<?php

declare(strict_types=1);

namespace Tests\Feature\Api\V1;

use App\Exceptions\ApiException;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Context;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use RuntimeException;
use Tests\TestCase;

/**
 * Proves the framework-level API contract: the client API is mounted under
 * /api/v1, and every failure renders the stable envelope of docs/09 Section 3
 * with no sensitive detail, whatever the debug mode.
 *
 * Routes here are test-only. Production endpoints are added by the wave tasks
 * that own them, so nothing in routes/api/v1 is required to run these tests.
 */
final class ApiFoundationTest extends TestCase
{
    private const SENSITIVE_MARKER = 'internal-detail-that-must-not-leak';

    protected function setUp(): void
    {
        parent::setUp();

        Route::middleware('api')->prefix('api/v1/testing')->group(function (): void {
            Route::post('validation', function (Request $request): void {
                $request->validate(['email' => ['required', 'email']]);
            });

            Route::get('authenticated', fn () => response()->json(['data' => []]))
                ->middleware('auth:sanctum');

            Route::get('forbidden', fn () => abort(403));

            Route::get('throttled', fn () => response()->json(['data' => []]))
                ->middleware('throttle:1,1');

            Route::get('unexpected', function (): void {
                throw new RuntimeException(self::SENSITIVE_MARKER);
            });

            Route::get('get-only', fn () => response()->json(['data' => []]));

            Route::get('malformed', fn () => abort(400, self::SENSITIVE_MARKER));

            Route::get('conflict', fn () => abort(409, self::SENSITIVE_MARKER));

            Route::get('unavailable', fn () => abort(503, self::SENSITIVE_MARKER));

            Route::get('aborted-with-detail', fn () => abort(500, self::SENSITIVE_MARKER));

            Route::get('business-rule', function (): void {
                throw ApiException::unprocessable('minimum_order_not_reached', [
                    'minimum_order_uzs' => 50000,
                    'shortfall_uzs' => 12000,
                ], self::SENSITIVE_MARKER);
            });

            Route::get('limited', function (): void {
                throw ApiException::rateLimited(45, self::SENSITIVE_MARKER);
            });
        });
    }

    public function test_client_api_is_mounted_under_v1(): void
    {
        $this->getJson('/api/v1/testing/authenticated')->assertStatus(401);

        $this->getJson('/api/testing/authenticated')->assertStatus(404);
    }

    public function test_unknown_api_path_returns_scope_safe_not_found(): void
    {
        $this->assertEnvelope($this->getJson('/api/v1/no-such-resource'), 404, 'resource_not_found');
    }

    public function test_validation_failure_returns_field_errors(): void
    {
        $response = $this->postJson('/api/v1/testing/validation', ['email' => 'not-an-email']);

        $response->assertStatus(422)
            ->assertJsonPath('code', 'validation_failed')
            ->assertJsonStructure(['message', 'code', 'errors' => ['email'], 'request_id']);
    }

    public function test_missing_authentication_returns_authentication_required(): void
    {
        $this->assertEnvelope($this->getJson('/api/v1/testing/authenticated'), 401, 'authentication_required');
    }

    public function test_denied_authorization_returns_forbidden(): void
    {
        $this->assertEnvelope($this->getJson('/api/v1/testing/forbidden'), 403, 'forbidden');
    }

    public function test_throttled_request_returns_rate_limited_and_keeps_backoff_headers(): void
    {
        $this->getJson('/api/v1/testing/throttled')->assertOk();

        $response = $this->getJson('/api/v1/testing/throttled');

        $this->assertEnvelope($response, 429, 'rate_limited');

        // Without Retry-After a client cannot back off correctly.
        $response->assertHeader('Retry-After');
        $response->assertHeader('X-RateLimit-Limit', '1');
        $response->assertHeader('X-RateLimit-Remaining', '0');
    }

    public function test_unexpected_failure_is_production_safe(): void
    {
        config(['app.debug' => false]);

        $this->assertEnvelope($this->getJson('/api/v1/testing/unexpected'), 500, 'server_error');
    }

    /**
     * The shipped .env.example enables debug, so the leak-proof guarantee has
     * to hold with debug on as well, not only in production configuration.
     */
    public function test_unexpected_failure_is_safe_even_with_debug_enabled(): void
    {
        config(['app.debug' => true]);

        $this->assertEnvelope($this->getJson('/api/v1/testing/unexpected'), 500, 'server_error');
    }

    public function test_malformed_request_keeps_its_status_with_its_own_code(): void
    {
        config(['app.debug' => true]);

        $this->assertEnvelope($this->getJson('/api/v1/testing/malformed'), 400, 'malformed_request');
    }

    public function test_conflict_keeps_its_status_with_the_generic_business_code(): void
    {
        config(['app.debug' => true]);

        $this->assertEnvelope($this->getJson('/api/v1/testing/conflict'), 409, 'business_conflict');
    }

    /**
     * A status with no code of its own must not escape the envelope, and 405
     * becomes a scope-safe 404 so the Allow header cannot disclose which
     * methods a path accepts.
     */
    public function test_unmapped_client_error_becomes_scope_safe_not_found(): void
    {
        config(['app.debug' => true]);

        $response = $this->postJson('/api/v1/testing/get-only');

        $this->assertEnvelope($response, 404, 'resource_not_found');
        $response->assertHeaderMissing('Allow');
    }

    public function test_provider_failure_keeps_its_status_with_provider_unavailable(): void
    {
        config(['app.debug' => true]);

        $this->assertEnvelope($this->getJson('/api/v1/testing/unavailable'), 503, 'provider_unavailable');
    }

    /**
     * abort(500, $message) must not pass its message through to the client.
     */
    public function test_aborted_request_does_not_leak_its_message(): void
    {
        config(['app.debug' => false]);

        $this->assertEnvelope($this->getJson('/api/v1/testing/aborted-with-detail'), 500, 'server_error');
    }

    public function test_business_rule_failure_carries_its_values_as_details(): void
    {
        config(['app.debug' => true]);

        $response = $this->getJson('/api/v1/testing/business-rule');

        $this->assertEnvelope($response, 422, 'minimum_order_not_reached', withDetails: true);
        $response->assertJsonPath('details.minimum_order_uzs', 50000)
            ->assertJsonPath('details.shortfall_uzs', 12000);
    }

    public function test_request_id_in_the_response_is_the_one_the_logs_carry(): void
    {
        config(['app.debug' => false]);

        $response = $this->getJson('/api/v1/testing/unexpected');

        $requestId = $response->json('request_id');
        $this->assertIsString($requestId);
        $this->assertMatchesRegularExpression('/^req_[0-9a-z]{26}$/', $requestId);

        // The middleware puts the identifier into the request context, which
        // the framework's log processor stamps on every log line, and which is
        // what lets support find the log from the response.
        $this->assertSame($requestId, Context::get('request_id'));
    }

    public function test_an_unmatched_route_answers_with_the_middleware_request_id(): void
    {
        // The renderer generates a fallback identifier when the middleware did
        // not run, so distinct identifiers prove nothing. Equality with the
        // context proves the middleware ran for a request matching no route.
        $first = $this->getJson('/api/v1/no-such-resource');
        $this->assertSame($first->json('request_id'), Context::get('request_id'));

        $second = $this->getJson('/api/v1/no-such-resource');
        $this->assertSame($second->json('request_id'), Context::get('request_id'));
        $this->assertNotSame($first->json('request_id'), $second->json('request_id'));
    }

    public function test_rate_limited_refusal_carries_retry_after(): void
    {
        $response = $this->getJson('/api/v1/testing/limited');

        $this->assertEnvelope($response, 429, 'rate_limited');
        $response->assertHeader('Retry-After', '45');
    }

    public function test_maintenance_mode_answers_service_unavailable_not_a_provider_failure(): void
    {
        config(['app.debug' => true]);

        $this->app->maintenanceMode()->activate(['retry' => 60, 'status' => 503]);

        try {
            $response = $this->getJson('/api/v1/testing/get-only');
        } finally {
            $this->app->maintenanceMode()->deactivate();
        }

        $this->assertEnvelope($response, 503, 'service_unavailable');
        $response->assertHeader('Retry-After', '60');
    }

    public function test_successful_responses_carry_no_request_id(): void
    {
        $response = $this->getJson('/api/v1/testing/get-only');

        $response->assertOk()->assertExactJson(['data' => []]);
        $response->assertHeaderMissing('X-Request-Id');
    }

    public function test_generated_demo_user_endpoint_is_absent(): void
    {
        $this->getJson('/api/user')->assertStatus(404);

        $this->getJson('/api/v1/user')->assertStatus(404);
    }

    /**
     * Asserts the full envelope: exact status, exact machine code, an `errors`
     * object that is really present and really empty, `details` present only
     * when expected, a well-formed `request_id`, and a body that carries no
     * exception detail.
     */
    private function assertEnvelope(TestResponse $response, int $status, string $code, bool $withDetails = false): void
    {
        $response->assertStatus($status)->assertJsonPath('code', $code);

        $body = $response->getContent();
        $this->assertIsString($body);

        $decoded = json_decode($body, true);
        $this->assertIsArray($decoded);
        $this->assertSame(
            $withDetails
                ? ['message', 'code', 'errors', 'details', 'request_id']
                : ['message', 'code', 'errors', 'request_id'],
            array_keys($decoded)
        );
        $this->assertIsString($decoded['message']);
        $this->assertMatchesRegularExpression('/^req_[0-9a-z]{26}$/', $decoded['request_id']);

        // json_decode gives [] for both {} and []; the raw text distinguishes them.
        $this->assertStringContainsString('"errors":{}', $body);

        foreach ([self::SENSITIVE_MARKER, 'RuntimeException', 'HttpException', 'vendor', 'trace', '.php'] as $leak) {
            $this->assertStringNotContainsString($leak, $body);
        }
    }
}
