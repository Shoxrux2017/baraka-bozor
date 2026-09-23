<?php

declare(strict_types=1);

namespace Tests\Feature\Identity;

use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * The factory is delivered by this task so that the `auth-backend` track needs
 * no path of the `wave-owner` track to write its tests. That makes it a public
 * contract of the schema task rather than a convenience, and the states another
 * track will reach for have to exist and have to produce rows PostgreSQL
 * accepts.
 *
 * Every test here saves the model. A factory that only builds in memory would
 * happily produce a Customer with a password, and the first task to use it would
 * discover the constraint instead.
 */
final class UserFactoryTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_makes_a_valid_staff_account_by_default(): void
    {
        $user = User::factory()->create();

        $this->assertTrue($user->isStaff(), 'The default should be usable wherever a Staff account is needed.');
        $this->assertNotNull($user->password, 'Staff must hold a password.');
        $this->assertSame(UserStatus::Active, $user->status);
        $this->assertFalse($user->must_change_password);
    }

    public function test_it_can_make_every_approved_role(): void
    {
        foreach (Role::cases() as $role) {
            $user = User::factory()->role($role)->create();

            $this->assertSame($role, $user->fresh()->role);
        }

        $this->assertSame(count(Role::cases()), DB::table('users')->count());
    }

    public function test_a_customer_gets_no_password_and_no_first_login_gate(): void
    {
        // Both are database CHECKs, so a factory that got this wrong would make
        // every Customer test fail on a constraint rather than on its subject.
        $user = User::factory()->customer()->create();

        $this->assertSame(Role::Customer, $user->role);
        $this->assertNull($user->password);
        $this->assertFalse($user->must_change_password);
    }

    public function test_it_can_make_a_blocked_account(): void
    {
        $user = User::factory()->blocked()->create();

        $this->assertSame(UserStatus::Blocked, $user->status);
        $this->assertNotNull(
            $user->blocked_at,
            'users_blocked_at_check requires the instant, so a blocked state without one is unusable.'
        );
    }

    public function test_it_can_set_the_first_login_gate(): void
    {
        $user = User::factory()->mustChangePassword()->create();

        $this->assertTrue($user->must_change_password);
        $this->assertTrue($user->isStaff(), 'Only Staff can carry the gate; a Customer holds no password.');
    }

    public function test_successive_accounts_do_not_collide_on_one_phone(): void
    {
        // users_phone_active_staff_unique allows one active Staff account per
        // phone, so a factory that repeated a number would fail as soon as a test
        // needed two of them.
        $users = User::factory()->count(5)->create();

        $this->assertCount(5, $users->pluck('phone')->unique());
    }

    public function test_every_phone_it_makes_satisfies_the_locked_format(): void
    {
        foreach (User::factory()->count(5)->create() as $user) {
            $this->assertMatchesRegularExpression('/^\+998[0-9]{9}$/', $user->phone);
        }
    }
}
