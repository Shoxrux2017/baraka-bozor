<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\Enums\Role;
use App\Models\User;
use App\Modules\Auth\CodeDelivery\FakeCodeSink;
use App\Modules\Auth\Models\StaffLoginStep;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Route;
use Illuminate\Testing\TestResponse;
use Laravel\Sanctum\PersonalAccessToken;
use Tests\TestCase;

/**
 * The staff password step: `POST /api/v1/auth/staff/step` and the `staff_step`
 * of the code verification — docs/09 Sections 7 and 8, `DL-77`.
 */
final class StaffStepTest extends TestCase
{
    use RefreshDatabase;

    private const PHONE = '+998901234567';

    private const PASSWORD = 'correct horse battery staple';

    private bool $verified = false;

    protected function setUp(): void
    {
        parent::setUp();

        // A stand-in for any later feature endpoint behind the first-login gate.
        Route::middleware(['api', 'protected'])->prefix('api/v1/testing')->group(function (): void {
            Route::get('protected', fn () => response()->json(['data' => ['ok' => true]]));
        });
    }

    public function test_a_phone_holding_only_a_customer_gets_no_staff_step(): void
    {
        $this->verifyPhone()->assertOk()->assertJsonPath('data.staff_step', null);
        $this->assertSame(0, StaffLoginStep::query()->count());
    }

    public function test_a_phone_holding_a_shopper_or_courier_gets_a_staff_step_beside_a_customer_token(): void
    {
        foreach ([Role::Shopper, Role::Courier] as $role) {
            StaffLoginStep::query()->delete();
            User::query()->where('phone', self::PHONE)->delete();
            User::factory()->role($role)->create(['phone' => self::PHONE, 'password' => self::PASSWORD]);

            $response = $this->verifyPhone()->assertOk();

            $step = $response->json('data.staff_step.token');
            $this->assertIsString($step);
            $this->assertSame(64, strlen($step));

            $expiresAt = Carbon::parse($response->json('data.staff_step.expires_at'));
            $this->assertEqualsWithDelta(now()->addSeconds(300)->getTimestamp(), $expiresAt->getTimestamp(), 5);

            $this->withToken($response->json('data.token'))->getJson('/api/v1/auth/me')
                ->assertOk()
                ->assertJsonPath('data.role', 'customer');

            $this->assertSame(1, StaffLoginStep::query()->count());
            $this->assertSame(1, StaffLoginStep::query()->where('token_hash', hash('sha256', $step))->count());
        }
    }

    public function test_an_operator_admin_or_manager_gets_no_staff_step(): void
    {
        foreach ([Role::Operator, Role::Admin, Role::Manager] as $role) {
            User::query()->where('phone', self::PHONE)->where('role', '<>', Role::Customer->value)->delete();
            User::factory()->role($role)->create(['phone' => self::PHONE, 'password' => self::PASSWORD]);

            $this->verifyPhone()->assertOk()->assertJsonPath('data.staff_step', null);
        }

        $this->assertSame(0, StaffLoginStep::query()->count());
    }

    public function test_a_blocked_shopper_still_gets_a_step_and_is_refused_at_the_password(): void
    {
        User::factory()->role(Role::Shopper)->blocked()->create(['phone' => self::PHONE, 'password' => self::PASSWORD]);

        $step = $this->verifyPhone()->assertOk()->json('data.staff_step.token');

        $this->assertIsString($step);
    }

    public function test_a_second_verification_consumes_the_earlier_open_step(): void
    {
        User::factory()->role(Role::Shopper)->create(['phone' => self::PHONE, 'password' => self::PASSWORD]);

        $first = $this->verifyPhone()->json('data.staff_step.token');
        $second = $this->verifyPhone()->json('data.staff_step.token');

        $this->assertNotSame($first, $second);
        $this->assertRefused($this->step($first, self::PASSWORD), 'staff_step_invalid');
        $this->step($second, self::PASSWORD)->assertOk();
    }

    public function test_the_step_with_the_right_password_issues_a_staff_session(): void
    {
        $shopper = User::factory()->role(Role::Shopper)->create(['phone' => self::PHONE, 'password' => self::PASSWORD]);
        $step = $this->verifyPhone()->json('data.staff_step.token');

        $response = $this->step($step, self::PASSWORD)->assertOk();

        $this->assertSame(
            ['id', 'role', 'phone', 'full_name', 'status', 'must_change_password', 'preferred_language'],
            array_keys($response->json('data.user'))
        );
        $this->withToken($response->json('data.token'))->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.role', 'shopper')
            ->assertJsonPath('data.id', $shopper->id);

        $this->assertNotNull(StaffLoginStep::query()->firstOrFail()->consumed_at);
        $this->assertNotNull($shopper->fresh()?->last_login_at);
    }

    public function test_a_step_is_single_use(): void
    {
        User::factory()->role(Role::Courier)->create(['phone' => self::PHONE, 'password' => self::PASSWORD]);
        $step = $this->verifyPhone()->json('data.staff_step.token');

        $this->step($step, self::PASSWORD)->assertOk();

        $this->assertRefused($this->step($step, self::PASSWORD), 'staff_step_invalid');
    }

    public function test_a_wrong_password_is_counted_and_the_fifth_one_exhausts_the_step(): void
    {
        User::factory()->role(Role::Shopper)->create(['phone' => self::PHONE, 'password' => self::PASSWORD]);
        $step = $this->verifyPhone()->json('data.staff_step.token');

        $this->assertRefused($this->step($step, 'wrong'), 'invalid_credentials');
        $this->assertSame(1, StaffLoginStep::query()->firstOrFail()->failed_attempts);

        for ($attempt = 2; $attempt <= 5; $attempt++) {
            $this->assertRefused($this->step($step, 'wrong'), 'invalid_credentials');
        }

        $this->assertRefused($this->step($step, self::PASSWORD), 'staff_step_invalid');
        $this->assertSame(0, PersonalAccessToken::query()->where('name', 'staff')->count());
    }

    public function test_a_blocked_shopper_with_the_right_password_is_account_blocked_and_the_step_is_spent(): void
    {
        User::factory()->role(Role::Shopper)->blocked()->create(['phone' => self::PHONE, 'password' => self::PASSWORD]);
        $step = $this->verifyPhone()->json('data.staff_step.token');

        $this->assertRefused($this->step($step, self::PASSWORD), 'account_blocked');

        $this->assertNotNull(StaffLoginStep::query()->firstOrFail()->consumed_at);
        $this->assertRefused($this->step($step, self::PASSWORD), 'staff_step_invalid');
        $this->assertSame(0, PersonalAccessToken::query()->where('name', 'staff')->count());
    }

    public function test_a_step_older_than_five_minutes_is_expired(): void
    {
        User::factory()->role(Role::Shopper)->create(['phone' => self::PHONE, 'password' => self::PASSWORD]);
        $step = $this->verifyPhone()->json('data.staff_step.token');

        $this->travel(301)->seconds();

        $this->assertRefused($this->step($step, self::PASSWORD), 'staff_step_expired');
    }

    public function test_an_unknown_token_is_invalid_and_a_malformed_body_is_a_validation_failure(): void
    {
        $this->assertRefused($this->step(str_repeat('a', 64), self::PASSWORD), 'staff_step_invalid');

        $this->postJson('/api/v1/auth/staff/step', ['password' => self::PASSWORD])
            ->assertStatus(422)->assertJsonValidationErrors(['staff_step']);
        $this->postJson('/api/v1/auth/staff/step', ['staff_step' => 'short', 'password' => self::PASSWORD])
            ->assertStatus(422)->assertJsonValidationErrors(['staff_step']);
        $this->postJson('/api/v1/auth/staff/step', ['staff_step' => str_repeat('a', 64)])
            ->assertStatus(422)->assertJsonValidationErrors(['password']);
    }

    public function test_the_first_login_gate_applies_after_the_step(): void
    {
        User::factory()->role(Role::Shopper)->mustChangePassword()->create(['phone' => self::PHONE, 'password' => self::PASSWORD]);
        $step = $this->verifyPhone()->json('data.staff_step.token');

        $token = $this->step($step, self::PASSWORD)
            ->assertOk()
            ->assertJsonPath('data.user.must_change_password', true)
            ->json('data.token');

        $this->withToken($token)->getJson('/api/v1/testing/protected')
            ->assertStatus(403)
            ->assertJsonPath('code', 'password_change_required');
    }

    public function test_twenty_one_attempts_from_one_address_are_rate_limited(): void
    {
        for ($attempt = 1; $attempt <= 20; $attempt++) {
            $this->assertRefused($this->step(str_repeat('a', 64), 'wrong'), 'staff_step_invalid');
        }

        $limited = $this->step(str_repeat('a', 64), 'wrong');
        $limited->assertStatus(429)->assertJsonPath('code', 'rate_limited');
        $limited->assertHeader('Retry-After');
    }

    private function verifyPhone(): TestResponse
    {
        // A resend inside sixty seconds is refused, so every further
        // verification in one test starts a minute later.
        if ($this->verified) {
            $this->travel(61)->seconds();
        }
        $this->verified = true;

        $this->postJson('/api/v1/auth/customer/code/request', ['phone' => self::PHONE])->assertOk();
        $code = $this->app->make(FakeCodeSink::class)->codeFor(self::PHONE);
        $this->assertNotNull($code);

        return $this->postJson('/api/v1/auth/customer/code/verify', ['phone' => self::PHONE, 'code' => $code]);
    }

    private function step(string $token, string $password, string $ip = '198.51.100.1'): TestResponse
    {
        return $this->withServerVariables(['REMOTE_ADDR' => $ip])
            ->postJson('/api/v1/auth/staff/step', ['staff_step' => $token, 'password' => $password]);
    }

    private function assertRefused(TestResponse $response, string $code): void
    {
        $response->assertStatus(401)->assertJsonPath('code', $code);
        $this->assertStringNotContainsString('"token"', (string) $response->getContent());
    }
}
