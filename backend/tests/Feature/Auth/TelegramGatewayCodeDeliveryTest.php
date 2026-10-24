<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Modules\Auth\CodeDelivery\CodeDeliveryFailed;
use App\Modules\Auth\CodeDelivery\CodeDeliveryGateway;
use App\Modules\Auth\CodeDelivery\TelegramGatewayCodeDelivery;
use App\Modules\Auth\Models\LoginChallenge;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\Request;
use Illuminate\Log\Events\MessageLogged;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use RuntimeException;
use Tests\TestCase;

/**
 * The Telegram Gateway adapter behind `CodeDeliveryGateway` (`DL-104`): a code
 * goes out as a check followed by a send, a number Telegram cannot reach is
 * `409 code_delivery_unavailable`, and no failure puts the code, the token or
 * the phone in a log or a message.
 */
final class TelegramGatewayCodeDeliveryTest extends TestCase
{
    use RefreshDatabase;

    private const PHONE = '+998901234567';

    private const BASE = 'https://gatewayapi.telegram.org';

    private const REFUSED = 'Telegram Gateway refused a login code.';

    /** @var list<array{message: string, context: array<string, mixed>}> */
    private array $warnings = [];

    protected function setUp(): void
    {
        parent::setUp();

        config(['login_codes.driver' => 'telegram', 'services.telegram_gateway.token' => 'tg-test-token']);
        Http::preventStrayRequests();

        Event::listen(MessageLogged::class, function (MessageLogged $event): void {
            if ($event->level === 'warning') {
                $this->warnings[] = ['message' => $event->message, 'context' => $event->context];
            }
        });
    }

    public function test_a_code_goes_out_as_a_check_then_a_send_under_its_request_id(): void
    {
        Http::fake([
            self::BASE.'/checkSendAbility' => Http::response([
                'ok' => true,
                'result' => ['request_id' => 'req-1', 'phone_number' => self::PHONE, 'request_cost' => 0.01],
            ]),
            self::BASE.'/sendVerificationMessage' => Http::response(['ok' => true, 'result' => ['request_id' => 'req-1']]),
        ]);

        $this->request()->assertOk()->assertJsonPath('data.channel', 'telegram');

        Http::assertSentCount(2);
        $sent = Http::recorded()->map(static fn (array $pair): Request => $pair[0])->values();

        $check = $sent[0];
        $this->assertSame('POST', $check->method());
        $this->assertSame(self::BASE.'/checkSendAbility', $check->url());
        $this->assertSame(['phone_number' => self::PHONE], $check->data());

        $send = $sent[1];
        $this->assertSame('POST', $send->method());
        $this->assertSame(self::BASE.'/sendVerificationMessage', $send->url());
        $data = $send->data();
        $this->assertSame(self::PHONE, $data['phone_number']);
        $this->assertSame('req-1', $data['request_id']);
        $this->assertSame(300, $data['ttl']);
        $this->assertMatchesRegularExpression('/^[0-9]{6}$/', (string) $data['code']);

        $challenge = LoginChallenge::query()->openFor(self::PHONE)->sole();
        $this->assertTrue(Hash::check((string) $data['code'], $challenge->code_hash));

        foreach ($sent as $call) {
            $this->assertSame('Bearer tg-test-token', $call->header('Authorization')[0] ?? null);
            $this->assertStringNotContainsString('tg-test-token', $call->url());
        }
    }

    /**
     * Telegram answered W4-4's unreachable number with a 200 (`DL-111`); the
     * 400 case keeps the status out of the decision.
     *
     * @return array<string, array{string, int}>
     */
    public static function unreachable(): array
    {
        return [
            'invalid' => ['PHONE_NUMBER_INVALID', 200],
            'not found' => ['PHONE_NUMBER_NOT_FOUND', 200],
            'not available' => ['PHONE_NUMBER_NOT_AVAILABLE', 200],
            'invalid under a 400' => ['PHONE_NUMBER_INVALID', 400],
        ];
    }

    #[DataProvider('unreachable')]
    public function test_a_number_telegram_cannot_reach_is_refused_without_a_challenge(string $error, int $status): void
    {
        Http::fake([self::BASE.'/*' => Http::response(['ok' => false, 'error' => $error], $status)]);

        $this->request()->assertStatus(409)->assertJsonPath('code', 'code_delivery_unavailable');

        $this->assertSame(0, LoginChallenge::query()->count());
        Http::assertSentCount(1);
        $this->assertSame([], $this->refusals());
    }

    /**
     * @return array<string, array{array<string, mixed>|string, int, string}>
     */
    public static function refusalCases(): array
    {
        return [
            'token invalid' => [['ok' => false, 'error' => 'ACCESS_TOKEN_INVALID'], 401, 'ACCESS_TOKEN_INVALID'],
            'balance' => [['ok' => false, 'error' => 'BALANCE_NOT_ENOUGH'], 400, 'BALANCE_NOT_ENOUGH'],
            'balance under a 200' => [['ok' => false, 'error' => 'BALANCE_NOT_ENOUGH'], 200, 'BALANCE_NOT_ENOUGH'],
            'flood' => [['ok' => false, 'error' => 'FLOOD_WAIT'], 429, 'FLOOD_WAIT'],
            'error with digits' => [['ok' => false, 'error' => 'CODE_123456'], 400, 'unreadable'],
            'html 502' => ['<html>Bad gateway</html>', 502, 'http_502'],
            'no request id' => [['ok' => true, 'result' => []], 200, 'unreadable'],
            'not json' => ['not json', 200, 'unreadable'],
        ];
    }

    /**
     * @param  array<string, mixed>|string  $body
     */
    #[DataProvider('refusalCases')]
    public function test_a_provider_refusal_is_provider_unavailable(array|string $body, int $status, string $reason): void
    {
        Http::fake([self::BASE.'/*' => Http::response($body, $status)]);

        $this->request()->assertStatus(503)->assertJsonPath('code', 'provider_unavailable');

        $this->assertSame(0, LoginChallenge::query()->count());
        Http::assertSentCount(1);
        $this->assertSame([['reason' => $reason]], $this->refusals());
    }

    public function test_a_check_that_times_out_is_provider_unavailable(): void
    {
        Http::fake([self::BASE.'/*' => Http::failedConnection()]);

        $this->request()->assertStatus(503)->assertJsonPath('code', 'provider_unavailable');

        Http::assertSentCount(1);
        $this->assertSame([['reason' => 'connection']], $this->refusals());
    }

    public function test_a_send_that_times_out_after_a_paid_check_is_not_retried(): void
    {
        Http::fake([
            self::BASE.'/checkSendAbility' => Http::response(['ok' => true, 'result' => ['request_id' => 'req-1']]),
            self::BASE.'/sendVerificationMessage' => Http::failedConnection(),
        ]);

        $this->request()->assertStatus(503)->assertJsonPath('code', 'provider_unavailable');

        $this->assertSame(0, LoginChallenge::query()->count());
        Http::assertSentCount(2);

        // The phone's next request is a new check and a new send; the sixth in
        // the hour is refused by the limit, not by the provider.
        $this->request()->assertStatus(503);
        Http::assertSentCount(4);
        $this->request()->assertStatus(503);
        $this->request()->assertStatus(503);
        $this->request()->assertStatus(503);
        $this->request()->assertStatus(429)->assertJsonPath('code', 'rate_limited');
    }

    public function test_the_adapter_message_carries_neither_the_code_nor_the_token(): void
    {
        Http::fake(static function (Request $request) {
            if (str_ends_with($request->url(), '/checkSendAbility')) {
                return Http::response(['ok' => true, 'result' => ['request_id' => 'req-1']]);
            }

            return Http::response('echo '.$request->body().' '.($request->header('Authorization')[0] ?? ''), 500);
        });

        try {
            (new TelegramGatewayCodeDelivery('tg-secret-token'))->deliver(self::PHONE, '482913');
            $this->fail('The delivery was expected to fail.');
        } catch (CodeDeliveryFailed $failure) {
            $this->assertNull($failure->getPrevious());
            $this->assertStringNotContainsString('482913', $failure->getMessage());
            $this->assertStringNotContainsString('tg-secret-token', $failure->getMessage());
            $this->assertStringNotContainsString(self::PHONE, $failure->getMessage());
        }
    }

    public function test_the_telegram_driver_needs_a_token(): void
    {
        config(['services.telegram_gateway.token' => '']);

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('TELEGRAM_GATEWAY_TOKEN');

        $this->app->make(CodeDeliveryGateway::class);
    }

    /**
     * The context of every refusal warning logged so far.
     *
     * @return list<array<string, mixed>>
     */
    private function refusals(): array
    {
        $contexts = [];

        foreach ($this->warnings as $warning) {
            if ($warning['message'] === self::REFUSED) {
                $contexts[] = $warning['context'];
            }
        }

        return $contexts;
    }

    private function request(): TestResponse
    {
        return $this->postJson('/api/v1/auth/customer/code/request', ['phone' => self::PHONE]);
    }
}
