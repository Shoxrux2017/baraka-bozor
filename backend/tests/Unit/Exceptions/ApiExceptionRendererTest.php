<?php

declare(strict_types=1);

namespace Tests\Unit\Exceptions;

use App\Exceptions\ApiExceptionRenderer;
use Illuminate\Http\Request;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use RuntimeException;
use Symfony\Component\HttpKernel\Exception\HttpException;

/**
 * Unit coverage for the status-to-code mapping, independent of the HTTP kernel.
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
            'approved 401' => [401, 401, 'authentication_required'],
            'approved 403' => [403, 403, 'forbidden'],
            'approved 404' => [404, 404, 'resource_not_found'],
            'approved 429' => [429, 429, 'rate_limited'],
            'unmapped 400 becomes scope-safe 404' => [400, 404, 'resource_not_found'],
            'unmapped 405 becomes scope-safe 404' => [405, 404, 'resource_not_found'],
            'unmapped 409 becomes scope-safe 404' => [409, 404, 'resource_not_found'],
            'unmapped 502 keeps its status' => [502, 502, 'server_error'],
            'unmapped 503 keeps its status' => [503, 503, 'server_error'],
        ];
    }

    #[DataProvider('statusCases')]
    public function test_http_exception_status_maps_to_an_approved_code(
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
     * @return array{message: string, code: string, errors: array<string, mixed>}
     */
    private function decode(string|false $json): array
    {
        $this->assertIsString($json);
        $decoded = json_decode($json, true);
        $this->assertIsArray($decoded);

        /** @var array{message: string, code: string, errors: array<string, mixed>} $decoded */
        return $decoded;
    }
}
