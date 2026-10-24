<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\Enums\Role;
use App\Models\User;
use App\Modules\Auth\Models\LoginChallenge;
use App\Modules\Auth\TestPhones;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Log\Events\MessageLogged;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Event;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * The daily ceiling of paid login-code checks for phones that hold no active
 * account (`DL-104` (9)): a phone with an account is never refused by it, a
 * test phone never counts, and the count starts again with the Tashkent day.
 */
final class LoginCodeCeilingTest extends TestCase
{
    use RefreshDatabase;

    private const HALF = 'Login code daily ceiling half used.';

    private const REACHED = 'Login code daily ceiling reached.';

    private const TEST_PHONE = '+998900000077';

    /** @var list<array{message: string, context: array<string, mixed>}> */
    private array $warnings = [];

    private int $requests = 0;

    protected function setUp(): void
    {
        parent::setUp();

        config(['login_codes.daily_limit' => 4]);

        Event::listen(MessageLogged::class, function (MessageLogged $event): void {
            if ($event->level === 'warning') {
                $this->warnings[] = ['message' => $event->message, 'context' => $event->context];
            }
        });
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();

        parent::tearDown();
    }

    public function test_new_phones_are_refused_above_the_ceiling(): void
    {
        foreach (range(1, 4) as $n) {
            $this->request($this->phone($n))->assertOk();
        }

        $this->request($this->phone(5))->assertStatus(503)->assertJsonPath('code', 'provider_unavailable');

        $this->assertSame(4, LoginChallenge::query()->count());
        $this->assertSame(0, LoginChallenge::query()->where('phone', $this->phone(5))->count());
    }

    public function test_existing_accounts_still_get_codes_above_the_ceiling(): void
    {
        $customer = User::factory()->customer()->create(['phone' => $this->phone(20)]);
        $shopper = User::factory()->role(Role::Shopper)->create(['phone' => $this->phone(21)]);
        User::factory()->customer()->blocked()->create(['phone' => $this->phone(22)]);

        foreach (range(1, 4) as $n) {
            $this->request($this->phone($n))->assertOk();
        }
        $this->request($this->phone(5))->assertStatus(503);

        $this->request($customer->phone)->assertOk();
        $this->request($shopper->phone)->assertOk();

        $token = $customer->createToken('customer')->plainTextToken;
        $this->flushHeaders();
        $this->withServerVariables(['REMOTE_ADDR' => $this->nextAddress()])
            ->withToken($token)
            ->postJson('/api/v1/customer/account/deletion-code')
            ->assertOk();

        $this->flushHeaders();
        $this->request($this->phone(22))->assertStatus(503)->assertJsonPath('code', 'provider_unavailable');
    }

    public function test_test_phones_never_count(): void
    {
        config(['login_codes.daily_limit' => 1, 'login_codes.test_phones' => [self::TEST_PHONE], 'login_codes.test_code' => '000000']);
        $this->app->forgetInstance(TestPhones::class);

        foreach (range(1, 3) as $ignored) {
            $this->request(self::TEST_PHONE)->assertOk()->assertJsonPath('data.channel', 'test');
        }

        $this->request($this->phone(1))->assertOk();
        $this->request($this->phone(2))->assertStatus(503);
    }

    public function test_warnings_at_half_and_at_the_ceiling_once_each(): void
    {
        foreach (range(1, 6) as $n) {
            $this->request($this->phone($n));

            if ($n === 1) {
                $this->assertSame(0, $this->warned(self::HALF));
            }
            if ($n === 2) {
                $this->assertSame(1, $this->warned(self::HALF));
                $this->assertSame(0, $this->warned(self::REACHED));
            }
            if ($n === 4) {
                $this->assertSame(1, $this->warned(self::REACHED));
            }
        }

        $this->assertSame(1, $this->warned(self::HALF));
        $this->assertSame(1, $this->warned(self::REACHED));

        foreach ($this->warnings as $warning) {
            if (in_array($warning['message'], [self::HALF, self::REACHED], true)) {
                $this->assertSame(['limit' => 4], $warning['context']);
            }

            $line = $warning['message'].json_encode($warning['context']);
            foreach (range(1, 6) as $n) {
                $this->assertStringNotContainsString(substr($this->phone($n), 1), $line);
            }
        }
    }

    public function test_the_ceiling_starts_again_with_the_tashkent_day(): void
    {
        $this->travelTo(Carbon::parse('2026-10-24 23:58:00', 'Asia/Tashkent'));

        foreach (range(1, 4) as $n) {
            $this->request($this->phone($n))->assertOk();
        }
        $this->request($this->phone(5))->assertStatus(503);

        $this->travelTo(Carbon::parse('2026-10-25 00:02:00', 'Asia/Tashkent'));

        $this->request($this->phone(6))->assertOk();
    }

    private function warned(string $message): int
    {
        return count(array_filter($this->warnings, static fn (array $w): bool => $w['message'] === $message));
    }

    private function phone(int $n): string
    {
        return '+99890100'.str_pad((string) $n, 4, '0', STR_PAD_LEFT);
    }

    private function nextAddress(): string
    {
        return '203.0.113.'.(++$this->requests);
    }

    private function request(string $phone): TestResponse
    {
        return $this->withServerVariables(['REMOTE_ADDR' => $this->nextAddress()])
            ->postJson('/api/v1/auth/customer/code/request', ['phone' => $phone]);
    }
}
