<?php

declare(strict_types=1);

namespace Tests\Feature\Console;

use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\User;
use Database\Seeders\WalkthroughSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Hash;
use RuntimeException;
use Tests\TestCase;

/**
 * `DL-35`: the walkthrough's staff accounts exist on the developer's machine
 * only, with a password from the local `.env`, and seeding twice changes
 * nothing.
 */
final class WalkthroughSeederTest extends TestCase
{
    use RefreshDatabase;

    private const PASSWORD = 'walkthrough-password';

    public function test_it_seeds_one_account_per_staff_role(): void
    {
        $this->asLocal(self::PASSWORD);

        $this->artisan('db:seed', ['--class' => WalkthroughSeeder::class])->assertSuccessful();

        $staff = User::query()->orderBy('phone')->get();
        $this->assertSame(
            ['+998900000002', '+998900000003', '+998900000004', '+998900000005', '+998900000006'],
            $staff->pluck('phone')->all(),
        );
        $this->assertSame(
            [Role::Shopper, Role::Courier, Role::Operator, Role::Admin, Role::Manager],
            $staff->pluck('role')->all(),
        );
        foreach ($staff as $user) {
            $this->assertSame(UserStatus::Active, $user->status);
            $this->assertTrue(Hash::check(self::PASSWORD, (string) $user->password));
            $gated = $user->role === Role::Courier;
            $this->assertSame($gated, $user->must_change_password);
            $this->assertSame($gated, $user->password_changed_at === null);
            $this->assertNull($user->created_by_user_id);
        }
    }

    public function test_seeding_again_changes_nothing_and_a_customer_on_the_phone_is_no_obstacle(): void
    {
        $this->asLocal(self::PASSWORD);
        $customer = User::factory()->customer()->create(['phone' => '+998900000002']);

        $this->artisan('db:seed', ['--class' => WalkthroughSeeder::class])->assertSuccessful();
        $admin = User::query()->where('role', Role::Admin->value)->sole();
        config(['walkthrough.staff_password' => 'another-password']);
        $this->artisan('db:seed', ['--class' => WalkthroughSeeder::class])->assertSuccessful();

        $this->assertSame(6, User::query()->count());
        $this->assertSame(Role::Customer, $customer->fresh()?->role);
        $this->assertSame($admin->password, $admin->fresh()?->password);
    }

    public function test_it_refuses_outside_the_local_environment(): void
    {
        $this->app->detectEnvironment(static fn (): string => 'production');
        config(['walkthrough.staff_password' => self::PASSWORD]);

        $this->assertRefused('The walkthrough accounts are for the local environment only.');
    }

    public function test_it_refuses_without_a_password(): void
    {
        $this->asLocal('');

        $this->assertRefused('Set WALKTHROUGH_STAFF_PASSWORD in backend/.env first.');
    }

    private function asLocal(string $password): void
    {
        $this->app->detectEnvironment(static fn (): string => 'local');
        config(['walkthrough.staff_password' => $password]);
    }

    private function assertRefused(string $message): void
    {
        // Held and asserted after the `try`: PHPUnit's own failure is a
        // `RuntimeException` too, and would be caught as the refusal.
        $refusal = null;
        try {
            // `--force` answers the production confirmation, as an operator
            // would; the seeder must refuse all the same.
            $this->artisan('db:seed', ['--class' => WalkthroughSeeder::class, '--force' => true])->run();
        } catch (RuntimeException $caught) {
            $refusal = $caught;
        }

        $this->assertNotNull($refusal, 'The seeder ran.');
        $this->assertSame($message, $refusal->getMessage());
        $this->assertSame(0, User::query()->count());
    }
}
