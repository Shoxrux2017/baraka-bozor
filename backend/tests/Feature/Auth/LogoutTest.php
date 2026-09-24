<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\Enums\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * `POST /api/v1/auth/logout` — docs/09 Section 11.
 */
final class LogoutTest extends TestCase
{
    use RefreshDatabase;

    public function test_logout_revokes_the_calling_token_and_no_other(): void
    {
        $courier = User::factory()->role(Role::Courier)->create();
        $phone = $courier->createToken('phone')->plainTextToken;
        $tablet = $courier->createToken('tablet')->plainTextToken;

        $this->withToken($phone)->postJson('/api/v1/auth/logout')->assertNoContent();

        $this->withToken($phone)->getJson('/api/v1/auth/me')
            ->assertStatus(401)
            ->assertJsonPath('code', 'authentication_required');
        $this->withToken($tablet)->getJson('/api/v1/auth/me')->assertOk();
        $this->assertSame(1, $courier->tokens()->count());
    }

    public function test_logout_works_while_the_first_login_gate_is_set(): void
    {
        $shopper = User::factory()->role(Role::Shopper)->mustChangePassword()->create();
        $token = $shopper->createToken('phone')->plainTextToken;

        $this->withToken($token)->postJson('/api/v1/auth/logout')->assertNoContent();
    }

    public function test_without_a_token_logout_is_authentication_required(): void
    {
        $this->postJson('/api/v1/auth/logout')->assertStatus(401)->assertJsonPath('code', 'authentication_required');
    }
}
