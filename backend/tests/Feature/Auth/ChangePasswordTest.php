<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\Enums\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * `POST /api/v1/auth/change-password` — docs/09 Section 10 and DL-9.
 */
final class ChangePasswordTest extends TestCase
{
    use RefreshDatabase;

    private const CURRENT = 'temporary password 1';

    private const NEW = 'a brand new password';

    public function test_a_staff_member_changes_the_password_and_the_gate_clears(): void
    {
        $shopper = User::factory()->role(Role::Shopper)->mustChangePassword()->create(['password' => self::CURRENT]);
        $token = $this->tokenFor($shopper);

        $this->change($token, self::CURRENT, self::NEW)->assertNoContent();

        $fresh = $shopper->fresh();
        $this->assertNotNull($fresh);
        $this->assertTrue(Hash::check(self::NEW, (string) $fresh->password));
        $this->assertFalse($fresh->must_change_password);
        $this->assertNotNull($fresh->password_changed_at);

        // The changed password is what logs in now.
        $this->postJson('/api/v1/auth/staff/login', ['phone' => $shopper->phone, 'password' => self::NEW])->assertOk();
        $this->postJson('/api/v1/auth/staff/login', ['phone' => $shopper->phone, 'password' => self::CURRENT])
            ->assertStatus(401);
    }

    public function test_every_other_token_of_the_account_is_revoked(): void
    {
        $operator = User::factory()->role(Role::Operator)->create(['password' => self::CURRENT]);
        $phone = $this->tokenFor($operator);
        $tablet = $this->tokenFor($operator);

        $this->change($phone, self::CURRENT, self::NEW)->assertNoContent();

        $this->withToken($phone)->getJson('/api/v1/auth/me')->assertOk();
        $this->withToken($tablet)->getJson('/api/v1/auth/me')->assertStatus(401);
        $this->assertSame(1, $operator->tokens()->count());
    }

    public function test_a_wrong_current_password_is_invalid_credentials_and_changes_nothing(): void
    {
        $operator = User::factory()->role(Role::Operator)->mustChangePassword()->create(['password' => self::CURRENT]);
        $token = $this->tokenFor($operator);

        $this->change($token, 'not it', self::NEW)->assertStatus(401)->assertJsonPath('code', 'invalid_credentials');

        $fresh = $operator->fresh();
        $this->assertNotNull($fresh);
        $this->assertTrue(Hash::check(self::CURRENT, (string) $fresh->password));
        $this->assertTrue($fresh->must_change_password);
    }

    public function test_the_new_password_is_validated_first_and_a_rejection_does_not_count(): void
    {
        $operator = User::factory()->role(Role::Operator)->create(['password' => self::CURRENT]);
        $token = $this->tokenFor($operator);

        // Too short, wrong confirmation, and a wrong current password at the
        // same time: validation answers, the current password is not checked.
        $this->change($token, 'not it', 'short', 'different')
            ->assertStatus(422)
            ->assertJsonValidationErrors(['new_password']);

        // Five wrong current passwords still fit, so the 422 consumed nothing.
        for ($attempt = 1; $attempt <= 5; $attempt++) {
            $this->change($token, 'not it', self::NEW)->assertStatus(401);
        }

        $this->change($token, 'not it', self::NEW)->assertStatus(429)->assertJsonPath('code', 'rate_limited');
    }

    public function test_the_limit_is_per_token_so_another_session_is_not_barred(): void
    {
        $admin = User::factory()->role(Role::Admin)->create(['password' => self::CURRENT]);
        $stolen = $this->tokenFor($admin);
        $own = $this->tokenFor($admin);

        for ($attempt = 1; $attempt <= 5; $attempt++) {
            $this->change($stolen, 'guess '.$attempt, self::NEW)->assertStatus(401);
        }

        $this->change($stolen, 'guess 6', self::NEW)->assertStatus(429);

        // The owner, on their own session, can still take the credential away.
        $this->change($own, self::CURRENT, self::NEW)->assertNoContent();
        $this->withToken($stolen)->getJson('/api/v1/auth/me')->assertStatus(401);
    }

    public function test_a_successful_change_clears_the_counter(): void
    {
        $operator = User::factory()->role(Role::Operator)->create(['password' => self::CURRENT]);
        $token = $this->tokenFor($operator);

        for ($attempt = 1; $attempt <= 4; $attempt++) {
            $this->change($token, 'not it', self::NEW)->assertStatus(401);
        }

        $this->change($token, self::CURRENT, self::NEW)->assertNoContent();

        for ($attempt = 1; $attempt <= 5; $attempt++) {
            $this->change($token, 'not it', 'yet another password')->assertStatus(401);
        }

        $this->change($token, 'not it', 'yet another password')->assertStatus(429);
    }

    public function test_the_lock_lifts_after_a_minute(): void
    {
        $operator = User::factory()->role(Role::Operator)->create(['password' => self::CURRENT]);
        $token = $this->tokenFor($operator);

        for ($attempt = 1; $attempt <= 5; $attempt++) {
            $this->change($token, 'not it', self::NEW)->assertStatus(401);
        }

        $limited = $this->change($token, self::CURRENT, self::NEW);
        $limited->assertStatus(429)->assertHeader('Retry-After');

        $this->travel(61)->seconds();

        $this->change($token, self::CURRENT, self::NEW)->assertNoContent();
    }

    public function test_a_customer_has_no_password_to_change(): void
    {
        $customer = User::factory()->customer()->create();

        $this->change($this->tokenFor($customer), 'anything at all', self::NEW)
            ->assertStatus(403)
            ->assertJsonPath('code', 'forbidden');
    }

    public function test_the_password_rule_is_ten_to_one_hundred_twenty_eight_characters(): void
    {
        $operator = User::factory()->role(Role::Operator)->create(['password' => self::CURRENT]);
        $token = $this->tokenFor($operator);

        $this->change($token, self::CURRENT, str_repeat('a', 9))->assertStatus(422)->assertJsonValidationErrors(['new_password']);
        $this->change($token, self::CURRENT, str_repeat('a', 129))->assertStatus(422)->assertJsonValidationErrors(['new_password']);
        $this->change($token, self::CURRENT, str_repeat('a', 10))->assertNoContent();
    }

    public function test_without_a_token_it_is_authentication_required(): void
    {
        $this->postJson('/api/v1/auth/change-password', [
            'current_password' => self::CURRENT,
            'new_password' => self::NEW,
            'new_password_confirmation' => self::NEW,
        ])->assertStatus(401)->assertJsonPath('code', 'authentication_required');
    }

    private function change(string $token, string $current, string $new, ?string $confirmation = null): TestResponse
    {
        return $this->withToken($token)->postJson('/api/v1/auth/change-password', [
            'current_password' => $current,
            'new_password' => $new,
            'new_password_confirmation' => $confirmation ?? $new,
        ]);
    }

    private function tokenFor(User $user): string
    {
        return $user->createToken('test')->plainTextToken;
    }
}
