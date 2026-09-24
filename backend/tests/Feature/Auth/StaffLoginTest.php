<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\Enums\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * `POST /api/v1/auth/staff/login` — docs/09 Section 8.
 */
final class StaffLoginTest extends TestCase
{
    use RefreshDatabase;

    private const PHONE = '+998901234567';

    private const PASSWORD = 'correct horse battery staple';

    public function test_active_staff_logs_in_and_receives_a_token_and_identity(): void
    {
        $operator = User::factory()->role(Role::Operator)->create([
            'phone' => self::PHONE,
            'password' => self::PASSWORD,
            'full_name' => 'Dilnoza Karimova',
        ]);

        $response = $this->login(self::PHONE, self::PASSWORD);

        $response->assertOk()
            ->assertJsonPath('data.user.id', $operator->id)
            ->assertJsonPath('data.user.role', 'operator')
            ->assertJsonPath('data.user.phone', self::PHONE)
            ->assertJsonPath('data.user.full_name', 'Dilnoza Karimova')
            ->assertJsonPath('data.user.status', 'active')
            ->assertJsonPath('data.user.must_change_password', false)
            ->assertJsonPath('data.user.preferred_language', 'uz');

        $token = $response->json('data.token');
        $this->assertIsString($token);

        // The body carries exactly the identity object; no hash, no internals.
        $this->assertSame(
            ['id', 'role', 'phone', 'full_name', 'status', 'must_change_password', 'preferred_language'],
            array_keys($response->json('data.user'))
        );
        $this->assertStringNotContainsString('$2y$', (string) $response->getContent());

        $this->assertNotNull($operator->fresh()?->last_login_at, 'last_login_at records the login');

        // The token opens the identity endpoint.
        $this->withToken($token)->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.id', $operator->id);
    }

    public function test_the_first_login_gate_is_reported(): void
    {
        User::factory()->role(Role::Shopper)->mustChangePassword()->create([
            'phone' => self::PHONE,
            'password' => self::PASSWORD,
        ]);

        $this->login(self::PHONE, self::PASSWORD)
            ->assertOk()
            ->assertJsonPath('data.user.must_change_password', true);
    }

    public function test_a_wrong_password_is_invalid_credentials(): void
    {
        User::factory()->role(Role::Operator)->create(['phone' => self::PHONE, 'password' => self::PASSWORD]);

        $this->assertRefused($this->login(self::PHONE, 'not the password'), 401, 'invalid_credentials');
    }

    public function test_an_unknown_phone_is_invalid_credentials_as_well(): void
    {
        // The same code as a wrong password: the response never says whether
        // the phone is known.
        $this->assertRefused($this->login('+998900000001', self::PASSWORD), 401, 'invalid_credentials');
    }

    public function test_a_customer_account_is_never_a_staff_login_target(): void
    {
        User::factory()->customer()->create(['phone' => self::PHONE]);

        $this->assertRefused($this->login(self::PHONE, self::PASSWORD), 401, 'invalid_credentials');
        $this->assertRefused($this->login(self::PHONE, ''), 422, 'validation_failed');
    }

    public function test_a_blocked_staff_account_with_the_right_password_is_account_blocked(): void
    {
        User::factory()->role(Role::Courier)->blocked()->create(['phone' => self::PHONE, 'password' => self::PASSWORD]);

        $this->assertRefused($this->login(self::PHONE, self::PASSWORD), 401, 'account_blocked');

        // With the wrong password the block is not disclosed.
        $this->assertRefused($this->login(self::PHONE, 'wrong'), 401, 'invalid_credentials');
    }

    public function test_the_active_account_wins_when_a_blocked_one_shares_the_phone(): void
    {
        User::factory()->role(Role::Shopper)->blocked()->create(['phone' => self::PHONE, 'password' => 'old password'.'!!']);
        $active = User::factory()->role(Role::Courier)->create(['phone' => self::PHONE, 'password' => self::PASSWORD]);

        $this->login(self::PHONE, self::PASSWORD)
            ->assertOk()
            ->assertJsonPath('data.user.id', $active->id)
            ->assertJsonPath('data.user.role', 'courier');
    }

    public function test_a_malformed_phone_is_a_validation_failure(): void
    {
        $response = $this->login('998901234567', self::PASSWORD);

        $this->assertRefused($response, 422, 'validation_failed');
        $response->assertJsonValidationErrors(['phone']);
    }

    public function test_unknown_fields_are_rejected(): void
    {
        User::factory()->role(Role::Operator)->create(['phone' => self::PHONE, 'password' => self::PASSWORD]);

        $response = $this->postJson('/api/v1/auth/staff/login', [
            'phone' => self::PHONE,
            'password' => self::PASSWORD,
            'role' => 'admin',
        ]);

        $this->assertRefused($response, 422, 'validation_failed');
        $response->assertJsonValidationErrors(['role']);
    }

    public function test_five_failures_per_phone_lock_that_phone_for_a_minute(): void
    {
        User::factory()->role(Role::Operator)->create(['phone' => self::PHONE, 'password' => self::PASSWORD]);

        for ($attempt = 1; $attempt <= 5; $attempt++) {
            $this->assertRefused($this->login(self::PHONE, 'wrong'), 401, 'invalid_credentials');
        }

        // The sixth attempt is refused before the password is even checked:
        // the right password does not get through either.
        $limited = $this->login(self::PHONE, self::PASSWORD);
        $this->assertRefused($limited, 429, 'rate_limited');
        $limited->assertHeader('Retry-After');

        // Another phone is not affected by this phone's counter.
        $this->assertRefused($this->login('+998900000002', 'wrong'), 401, 'invalid_credentials');

        $this->travel(61)->seconds();

        $this->login(self::PHONE, self::PASSWORD)->assertOk();
    }

    public function test_a_successful_login_clears_the_phone_counter(): void
    {
        User::factory()->role(Role::Operator)->create(['phone' => self::PHONE, 'password' => self::PASSWORD]);

        for ($attempt = 1; $attempt <= 4; $attempt++) {
            $this->login(self::PHONE, 'wrong');
        }

        $this->login(self::PHONE, self::PASSWORD)->assertOk();

        // Five more failures fit before the limit, so the counter was cleared.
        for ($attempt = 1; $attempt <= 5; $attempt++) {
            $this->assertRefused($this->login(self::PHONE, 'wrong'), 401, 'invalid_credentials');
        }

        $this->assertRefused($this->login(self::PHONE, 'wrong'), 429, 'rate_limited');
    }

    public function test_twenty_failures_per_address_lock_that_address(): void
    {
        for ($attempt = 1; $attempt <= 20; $attempt++) {
            $phone = sprintf('+99890%07d', $attempt);
            $this->assertRefused($this->login($phone, 'wrong', '203.0.113.10'), 401, 'invalid_credentials');
        }

        $this->assertRefused($this->login('+998901111111', 'wrong', '203.0.113.10'), 429, 'rate_limited');

        // A different address walks in unaffected.
        $this->assertRefused($this->login('+998901111111', 'wrong', '203.0.113.11'), 401, 'invalid_credentials');
    }

    public function test_a_successful_login_does_not_clear_the_address_counter(): void
    {
        User::factory()->role(Role::Operator)->create(['phone' => self::PHONE, 'password' => self::PASSWORD]);

        for ($attempt = 1; $attempt <= 19; $attempt++) {
            $this->login(sprintf('+99890%07d', $attempt), 'wrong', '203.0.113.10');
        }

        $this->login(self::PHONE, self::PASSWORD, '203.0.113.10')->assertOk();

        // One more failure reaches twenty; the login in between cleared nothing
        // for the address, so a stranger sharing it cannot be helped by it.
        $this->login('+998901111111', 'wrong', '203.0.113.10');
        $this->assertRefused($this->login('+998901111112', 'wrong', '203.0.113.10'), 429, 'rate_limited');
    }

    private function login(string $phone, string $password, string $ip = '198.51.100.1'): TestResponse
    {
        return $this->withServerVariables(['REMOTE_ADDR' => $ip])
            ->postJson('/api/v1/auth/staff/login', ['phone' => $phone, 'password' => $password]);
    }

    private function assertRefused(TestResponse $response, int $status, string $code): void
    {
        $response->assertStatus($status)->assertJsonPath('code', $code);
        $this->assertStringNotContainsString('token', (string) $response->getContent());
    }
}
