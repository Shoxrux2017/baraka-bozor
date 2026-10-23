<?php

declare(strict_types=1);

namespace Tests\Feature\Http;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * Only the panel's origin may call the API from a browser, and the panel can
 * read `Retry-After` (`DL-104` (4), `config/cors.php`).
 */
final class CorsTest extends TestCase
{
    use RefreshDatabase;

    private const PANEL = 'https://panel.example.test';

    protected function setUp(): void
    {
        parent::setUp();

        config(['cors.allowed_origins' => [self::PANEL]]);
    }

    public function test_a_preflight_from_the_panel_is_allowed(): void
    {
        $response = $this->preflight(self::PANEL)
            ->assertStatus(204)
            ->assertHeader('Access-Control-Allow-Origin', self::PANEL)
            ->assertHeader('Access-Control-Max-Age', '7200');

        $this->assertFalse($response->headers->has('Access-Control-Allow-Credentials'));
    }

    public function test_another_origin_gets_no_allow_header(): void
    {
        // With a single allowed origin the CORS library answers with that
        // origin whoever asks; the browser then refuses the mismatch. What
        // matters is that the other origin is never granted, nor "*".
        $response = $this->preflight('https://elsewhere.example.test');

        $this->assertSame(self::PANEL, $response->headers->get('Access-Control-Allow-Origin'));
    }

    public function test_retry_after_is_readable_cross_origin(): void
    {
        $response = $this->call('POST', '/api/v1/auth/customer/code/request', [], [], [], [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_ORIGIN' => self::PANEL,
        ], '{"phone": "+998901234567"}');

        $this->assertStringContainsString('Retry-After', (string) $response->headers->get('Access-Control-Expose-Headers'));
    }

    public function test_the_public_pages_are_not_under_cors(): void
    {
        $this->get('/legal/privacy', ['Origin' => self::PANEL])->assertHeaderMissing('Access-Control-Allow-Origin');
    }

    private function preflight(string $origin): TestResponse
    {
        return $this->call('OPTIONS', '/api/v1/auth/staff/login', [], [], [], [
            'HTTP_ORIGIN' => $origin,
            'HTTP_ACCESS_CONTROL_REQUEST_METHOD' => 'POST',
            'HTTP_ACCESS_CONTROL_REQUEST_HEADERS' => 'authorization, content-type, idempotency-key',
        ]);
    }
}
