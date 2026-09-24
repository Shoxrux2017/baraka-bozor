<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

/**
 * `GET|PATCH /api/v1/auth/me` (docs/09 Section 9), the sliding token lifetime
 * and the blocked re-check (docs/07 Section 8), and the first-login gate
 * (BR-ROLE-006) through the `protected` middleware group.
 */
final class CurrentUserTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        // A stand-in for any later feature endpoint: it declares the
        // `protected` group and nothing else, which is all the gate needs.
        Route::middleware(['api', 'protected'])->prefix('api/v1/testing')->group(function (): void {
            Route::get('protected', fn () => response()->json(['data' => ['ok' => true]]));
        });
    }

    public function test_staff_identity_is_returned(): void
    {
        $admin = User::factory()->role(Role::Admin)->create(['full_name' => 'Ulugbek']);

        $this->withToken($this->tokenFor($admin))->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertExactJson(['data' => [
                'id' => $admin->id,
                'role' => 'admin',
                'phone' => $admin->phone,
                'full_name' => 'Ulugbek',
                'status' => 'active',
                'must_change_password' => false,
                'preferred_language' => 'uz',
            ]]);
    }

    public function test_customer_identity_is_returned_the_same_way(): void
    {
        $customer = User::factory()->customer()->create(['full_name' => null]);

        $this->withToken($this->tokenFor($customer))->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.role', 'customer')
            ->assertJsonPath('data.full_name', null)
            ->assertJsonPath('data.must_change_password', false);
    }

    public function test_without_a_token_identity_is_authentication_required(): void
    {
        $this->getJson('/api/v1/auth/me')->assertStatus(401)->assertJsonPath('code', 'authentication_required');
    }

    public function test_preferred_language_can_be_changed_by_any_role(): void
    {
        $customer = User::factory()->customer()->create();

        $this->withToken($this->tokenFor($customer))
            ->patchJson('/api/v1/auth/me', ['preferred_language' => 'ru'])
            ->assertOk()
            ->assertJsonPath('data.preferred_language', 'ru');

        $this->assertSame('ru', $customer->fresh()?->preferred_language);
    }

    public function test_an_unknown_language_or_field_is_a_validation_failure(): void
    {
        $token = $this->tokenFor(User::factory()->role(Role::Shopper)->create());

        $this->withToken($token)->patchJson('/api/v1/auth/me', ['preferred_language' => 'en'])
            ->assertStatus(422)->assertJsonValidationErrors(['preferred_language']);

        $this->withToken($token)->patchJson('/api/v1/auth/me', ['preferred_language' => 'ru', 'role' => 'admin'])
            ->assertStatus(422)->assertJsonValidationErrors(['role']);

        $this->withToken($token)->patchJson('/api/v1/auth/me', ['full_name' => 'x'])
            ->assertStatus(422)->assertJsonValidationErrors(['preferred_language', 'full_name']);
    }

    public function test_a_valid_token_on_a_blocked_account_is_account_blocked_and_the_tokens_are_gone(): void
    {
        $operator = User::factory()->role(Role::Operator)->create();
        $token = $this->tokenFor($operator);
        $this->tokenFor($operator);

        // Blocked after the tokens were issued, by a path that forgot to
        // revoke them: the per-request check still refuses.
        $operator->forceFill(['status' => UserStatus::Blocked, 'blocked_at' => now()])->save();

        $this->withToken($token)->getJson('/api/v1/auth/me')
            ->assertStatus(401)
            ->assertJsonPath('code', 'account_blocked');

        $this->assertSame(0, $operator->tokens()->count(), 'the refusal deletes every token of the account');
    }

    public function test_a_token_unused_for_thirty_days_is_refused_and_deleted(): void
    {
        $operator = User::factory()->role(Role::Operator)->create();
        $token = $this->tokenFor($operator);

        $this->travel(31)->days();

        $this->withToken($token)->getJson('/api/v1/auth/me')
            ->assertStatus(401)
            ->assertJsonPath('code', 'authentication_required');

        $this->assertSame(0, $operator->tokens()->count(), 'a stale token is deleted on sight');
    }

    public function test_use_within_thirty_days_keeps_the_token_alive(): void
    {
        $operator = User::factory()->role(Role::Operator)->create();
        $token = $this->tokenFor($operator);

        $this->travel(29)->days();
        $this->withToken($token)->getJson('/api/v1/auth/me')->assertOk();

        // The use just now restarted the window: 29 more days are fine.
        $this->travel(29)->days();
        $this->withToken($token)->getJson('/api/v1/auth/me')->assertOk();

        $this->travel(31)->days();
        $this->withToken($token)->getJson('/api/v1/auth/me')->assertStatus(401);
    }

    public function test_the_lifetime_is_measured_from_last_use_not_from_issue(): void
    {
        $operator = User::factory()->role(Role::Operator)->create();
        $token = $this->tokenFor($operator);

        // Issued 40 days ago, used 10 days ago: alive.
        DB::table('personal_access_tokens')->update([
            'created_at' => now()->subDays(40),
            'last_used_at' => now()->subDays(10),
        ]);

        $this->withToken($token)->getJson('/api/v1/auth/me')->assertOk();
    }

    public function test_the_first_login_gate_blocks_protected_endpoints_but_not_onboarding(): void
    {
        $shopper = User::factory()->role(Role::Shopper)->mustChangePassword()->create();
        $token = $this->tokenFor($shopper);

        $this->withToken($token)->getJson('/api/v1/testing/protected')
            ->assertStatus(403)
            ->assertJsonPath('code', 'password_change_required');

        $this->withToken($token)->getJson('/api/v1/auth/me')->assertOk();
        $this->withToken($token)->patchJson('/api/v1/auth/me', ['preferred_language' => 'ru'])->assertOk();

        $shopper->forceFill(['must_change_password' => false])->save();

        $this->withToken($token)->getJson('/api/v1/testing/protected')->assertOk();
    }

    public function test_the_protected_group_refuses_a_blocked_account_before_the_gate(): void
    {
        $shopper = User::factory()->role(Role::Shopper)->mustChangePassword()->create();
        $token = $this->tokenFor($shopper);
        $shopper->forceFill(['status' => UserStatus::Blocked, 'blocked_at' => now()])->save();

        $this->withToken($token)->getJson('/api/v1/testing/protected')
            ->assertStatus(401)
            ->assertJsonPath('code', 'account_blocked');
    }

    private function tokenFor(User $user): string
    {
        return $user->createToken('test')->plainTextToken;
    }
}
