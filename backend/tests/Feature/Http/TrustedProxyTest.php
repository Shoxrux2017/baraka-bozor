<?php

declare(strict_types=1);

namespace Tests\Feature\Http;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use Symfony\Component\HttpFoundation\Response;
use Tests\TestCase;

/**
 * The per-IP limit counts the client a trusted sender names and cannot be
 * dodged by a sender that is not trusted (`config/trustedproxy.php`,
 * `DL-104` (4)). This guards the configuration, not the topology: whether the
 * sender is the edge network's gateway or a proxy hop is the deployment's
 * (`DL-107`).
 */
final class TrustedProxyTest extends TestCase
{
    use RefreshDatabase;

    private const PROXY = '172.30.250.2';

    protected function setUp(): void
    {
        parent::setUp();

        config(['trustedproxy.proxies' => ['172.30.250.0/28']]);
    }

    public function test_behind_the_proxy_the_limit_counts_each_client(): void
    {
        for ($attempt = 1; $attempt <= 10; $attempt++) {
            $this->requestCode(self::PROXY, '203.0.113.10', $attempt)->assertOk();
        }

        $this->requestCode(self::PROXY, '203.0.113.10', 11)
            ->assertStatus(429)
            ->assertJsonPath('code', 'rate_limited');

        $this->requestCode(self::PROXY, '203.0.113.11', 11)->assertOk();
    }

    public function test_an_untrusted_sender_cannot_choose_its_address(): void
    {
        for ($attempt = 1; $attempt <= 10; $attempt++) {
            $this->requestCode('198.51.100.7', '203.0.113.'.$attempt, $attempt)->assertOk();
        }

        $this->requestCode('198.51.100.7', '203.0.113.99', 11)
            ->assertStatus(429)
            ->assertJsonPath('code', 'rate_limited');
    }

    public function test_a_forwarded_port_from_a_trusted_sender_is_not_believed(): void
    {
        Route::get('/probe-port', fn (Request $request) => (string) $request->getPort());

        $own = $this->withServerVariables(['REMOTE_ADDR' => self::PROXY])->get('/probe-port')->assertOk()->getContent();

        $this->withServerVariables(['REMOTE_ADDR' => self::PROXY])
            ->withHeader('X-Forwarded-Port', '1234')
            ->get('/probe-port')
            ->assertOk()
            ->assertContent((string) $own);
    }

    /**
     * @return TestResponse<Response>
     */
    private function requestCode(string $remote, string $forwardedFor, int $phoneNumber): TestResponse
    {
        return $this->withServerVariables(['REMOTE_ADDR' => $remote])
            ->withHeader('X-Forwarded-For', $forwardedFor)
            ->postJson('/api/v1/auth/customer/code/request', ['phone' => sprintf('+99890%07d', $phoneNumber)]);
    }
}
