<?php

declare(strict_types=1);

namespace Tests\Unit\Exceptions;

use App\Exceptions\ApiException;
use App\Exceptions\ApiExceptionRenderer;
use App\Http\Middleware\AssignRequestId;
use Illuminate\Http\Request;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use RuntimeException;
use Symfony\Component\HttpKernel\Exception\HttpException;

/**
 * Unit coverage for the status-to-code table and the envelope shape,
 * independent of the HTTP kernel.
 *
 * The feature test proves the wiring; this proves the table, including the
 * statuses that are awkward to reach through a real request.
 */
final class ApiExceptionRendererTest extends TestCase
{
    /**
     * @return array<string, array{int, int, string}>
     */
    public static function statusCases(): array
    {
        return [
            'mapped 400' => [400, 400, 'malformed_request'],
            'mapped 401' => [401, 401, 'authentication_required'],
            'mapped 403' => [403, 403, 'forbidden'],
            'mapped 404' => [404, 404, 'resource_not_found'],
            'mapped 409' => [409, 409, 'business_conflict'],
            'mapped 422' => [422, 422, 'validation_failed'],
            'mapped 429' => [429, 429, 'rate_limited'],
            'mapped 502' => [502, 502, 'provider_unavailable'],
            'mapped 503' => [503, 503, 'provider_unavailable'],
            'unmapped 405 becomes scope-safe 404' => [405, 404, 'resource_not_found'],
            'unmapped 418 becomes scope-safe 404' => [418, 404, 'resource_not_found'],
            'unmapped 504 keeps its status' => [504, 504, 'server_error'],
        ];
    }

    #[DataProvider('statusCases')]
    public function test_http_exception_status_maps_to_a_stable_code(
        int $thrown,
        int $expectedStatus,
        string $expectedCode,
    ): void {
        $response = ApiExceptionRenderer::render(
            new HttpException($thrown, 'sensitive detail'),
            Request::create('/api/v1/anything'),
        );

        $this->assertNotNull($response);
        $this->assertSame($expectedStatus, $response->getStatusCode());

        $payload = $this->decode($response->getContent());
        $this->assertSame($expectedCode, $payload['code']);
        $this->assertSame([], $payload['errors']);
        $this->assertArrayNotHasKey('details', $payload);
        $this->assertStringNotContainsString('sensitive detail', (string) $response->getContent());
    }

    public function test_unknown_throwable_is_a_server_error(): void
    {
        $response = ApiExceptionRenderer::render(
            new RuntimeException('sensitive detail'),
            Request::create('/api/v1/anything'),
        );

        $this->assertNotNull($response);
        $this->assertSame(500, $response->getStatusCode());
        $this->assertSame('server_error', $this->decode($response->getContent())['code']);
    }

    public function test_api_exception_renders_its_code_status_and_details(): void
    {
        $response = ApiExceptionRenderer::render(
            ApiException::unprocessable('minimum_order_not_reached', [
                'minimum_order_uzs' => 50000,
                'shortfall_uzs' => 12000,
            ], 'subtotal 38000 below minimum 50000'),
            Request::create('/api/v1/customer/checkout/preview'),
        );

        $this->assertNotNull($response);
        $this->assertSame(422, $response->getStatusCode());

        $payload = $this->decode($response->getContent());
        $this->assertSame('minimum_order_not_reached', $payload['code']);
        $this->assertSame(['minimum_order_uzs' => 50000, 'shortfall_uzs' => 12000], $payload['details']);
        $this->assertSame([], $payload['errors']);
        $this->assertSame(
            ['message', 'code', 'errors', 'details', 'request_id'],
            array_keys($payload),
            'details sits between errors and request_id, as docs/09 Section 3 shows it'
        );

        // The developer message never reaches the client.
        $this->assertStringNotContainsString('38000', (string) $response->getContent());
    }

    public function test_api_exception_without_details_omits_the_key(): void
    {
        $response = ApiExceptionRenderer::render(
            ApiException::conflict('order_editing_locked'),
            Request::create('/api/v1/customer/orders/x/items'),
        );

        $this->assertNotNull($response);
        $this->assertSame(409, $response->getStatusCode());

        $payload = $this->decode($response->getContent());
        $this->assertSame('order_editing_locked', $payload['code']);
        $this->assertArrayNotHasKey('details', $payload);
    }

    public function test_request_id_is_taken_from_the_middleware_attribute(): void
    {
        $request = Request::create('/api/v1/anything');
        $request->attributes->set(AssignRequestId::ATTRIBUTE, 'req_01hzz000000000000000000000');

        $response = ApiExceptionRenderer::render(new HttpException(404), $request);

        $this->assertNotNull($response);
        $this->assertSame('req_01hzz000000000000000000000', $this->decode($response->getContent())['request_id']);
    }

    public function test_request_id_is_generated_when_the_middleware_did_not_run(): void
    {
        // A failure raised before the middleware stack — or in a unit test —
        // still answers with an identifier, so no error response ever lacks one.
        $response = ApiExceptionRenderer::render(new HttpException(404), Request::create('/api/v1/anything'));

        $this->assertNotNull($response);
        $this->assertMatchesRegularExpression(
            '/^req_[0-9a-z]{26}$/',
            $this->decode($response->getContent())['request_id']
        );
    }

    public function test_non_api_requests_are_left_to_the_framework(): void
    {
        $this->assertNull(ApiExceptionRenderer::render(
            new RuntimeException('boom'),
            Request::create('/up'),
        ));
    }

    public function test_errors_is_always_encoded_as_an_object(): void
    {
        $response = ApiExceptionRenderer::render(
            new HttpException(404),
            Request::create('/api/v1/anything'),
        );

        $this->assertNotNull($response);
        $this->assertStringContainsString('"errors":{}', (string) $response->getContent());
    }

    /**
     * @return array<string, mixed>
     */
    private function decode(string|false $json): array
    {
        $this->assertIsString($json);
        $decoded = json_decode($json, true);
        $this->assertIsArray($decoded);

        /** @var array<string, mixed> $decoded */
        return $decoded;
    }
}
