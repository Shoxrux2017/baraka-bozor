<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\User;
use Illuminate\Database\Seeder;
use RuntimeException;

/**
 * The staff accounts a wave's real-stack walkthrough signs in with (`DL-35`),
 * on the local development database and nowhere else.
 *
 * One account per staff role on the fixed phones below; the Courier starts
 * behind the first-login gate (`BR-ROLE-005`), so a walkthrough meets it.
 * Customers are not seeded: the code login creates them.
 *
 * The password comes from `WALKTHROUGH_STAFF_PASSWORD` in the gitignored
 * `backend/.env`, so the repository carries none, and it is never printed.
 * Idempotent: a phone that already has a staff account is left as it is.
 */
final class WalkthroughSeeder extends Seeder
{
    /**
     * Phone => role, and whether the account starts behind the gate.
     *
     * @var array<string, array{Role, bool}>
     */
    private const STAFF = [
        '+998900000002' => [Role::Shopper, false],
        '+998900000003' => [Role::Courier, true],
        '+998900000004' => [Role::Operator, false],
        '+998900000005' => [Role::Admin, false],
        '+998900000006' => [Role::Manager, false],
    ];

    public function run(): void
    {
        // An Admin with a known password is a login bypass anywhere but the
        // developer's own machine; `BR-ROLE-009` leaves the first real Admin
        // to `bootstrap:first-admin`.
        if (! app()->environment('local')) {
            throw new RuntimeException('The walkthrough accounts are for the local environment only.');
        }

        $password = config('walkthrough.staff_password');
        if (! is_string($password) || $password === '') {
            throw new RuntimeException('Set WALKTHROUGH_STAFF_PASSWORD in backend/.env first.');
        }

        foreach (self::STAFF as $phone => [$role, $gate]) {
            // A Customer and a Staff account may share a phone (`BR-ROLE-010`);
            // only a staff account makes this phone's seed redundant.
            if (User::query()->where('phone', $phone)->where('role', '!=', Role::Customer->value)->exists()) {
                $this->command->line("exists  {$phone}");

                continue;
            }

            $user = new User;
            // Assigned rather than mass-assigned, as `bootstrap:first-admin`
            // does: `role` and `status` stay out of `$fillable`.
            $user->forceFill([
                'role' => $role,
                'phone' => $phone,
                'full_name' => ucfirst($role->value).' Walkthrough',
                'password' => $password,
                'status' => UserStatus::Active,
                'must_change_password' => $gate,
                'password_changed_at' => $gate ? null : now(),
                'created_by_user_id' => null,
            ])->save();

            $this->command->line("created {$phone} {$role->value}".($gate ? ' behind the first-login gate' : ''));
        }
    }
}
