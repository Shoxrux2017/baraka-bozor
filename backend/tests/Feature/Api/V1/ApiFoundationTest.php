<?php

declare(strict_types=1);

namespace Tests\Feature\Api\V1;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use RuntimeException;
use Tests\TestCase;

/**
 * Proves the framework-level API contract: the client API is mounted under
 * /api/v1, and every failure renders the stable envelope with no sensitive
 * detail, whatever the debug mode.
 *
 * Routes here are test-only. Production endpoints are added by the Stage tasks
 * that own them, so nothing in routes/api.php is required to run these tests.
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

            Route::get('unavailable', fn () => abort(503, self::SENSITIVE_MARKER));

            Route::get('aborted-with-detail', fn () => abort(500, self::SENSITIVE_MARKER));
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
            ->assertJsonStructure(['message', 'code', 'errors' => ['email']]);
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

    /**
     * A status with no approved machine code must not escape the envelope.
     * 405 also becomes a scope-safe 404 so the Allow header cannot disclose
     * which methods a path accepts.
     */
    public function test_unmapped_client_error_becomes_scope_safe_not_found(): void
    {
        config(['app.debug' => true]);

        $response = $this->postJson('/api/v1/testing/get-only');

        $this->assertEnvelope($response, 404, 'resource_not_found');
        $response->assertHeaderMissing('Allow');
    }

    public function test_unmapped_server_error_keeps_its_status_and_is_safe(): void
    {
        config(['app.debug' => true]);

        $this->assertEnvelope($this->getJson('/api/v1/testing/unavailable'), 503, 'server_error');
    }

    /**
     * abort(500, $message) must not pass its message through to the client.
     */
    public function test_aborted_request_does_not_leak_its_message(): void
    {
        config(['app.debug' => false]);

        $this->assertEnvelope($this->getJson('/api/v1/testing/aborted-with-detail'), 500, 'server_error');
    }

    public function test_generated_demo_user_endpoint_is_absent(): void
    {
        $this->getJson('/api/user')->assertStatus(404);

        $this->getJson('/api/v1/user')->assertStatus(404);
    }

    /**
     * Asserts the full locked envelope: exact status, exact machine code, an
     * `errors` object that is really present and really empty, and a body that
     * carries no exception detail.
     */
    private function assertEnvelope(TestResponse $response, int $status, string $code): void
    {
        $response->assertStatus($status)->assertJsonPath('code', $code);

        $body = $response->getContent();
        $this->assertIsString($body);

        $decoded = json_decode($body, true);
        $this->assertIsArray($decoded);
        $this->assertSame(['message', 'code', 'errors'], array_keys($decoded));
        $this->assertIsString($decoded['message']);

        // json_decode gives [] for both {} and []; the raw text distinguishes them.
        $this->assertStringContainsString('"errors":{}', $body);

        foreach ([self::SENSITIVE_MARKER, 'RuntimeException', 'HttpException', 'vendor', 'trace', '.php'] as $leak) {
            $this->assertStringNotContainsString($leak, $body);
        }
    }
}
