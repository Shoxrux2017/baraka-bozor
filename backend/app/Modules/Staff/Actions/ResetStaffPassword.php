<?php

declare(strict_types=1);

namespace App\Modules\Staff\Actions;

use App\Exceptions\ApiException;
use App\Models\User;
use App\Modules\Notifications\Actions\RevokePushDevice;
use App\Modules\Staff\StaffDirectory;
use App\Modules\Staff\TemporaryCredentials;
use App\Modules\Staff\TemporaryPassword;
use App\Support\Scope\ScopedLookup;
use Illuminate\Support\Facades\DB;

/**
 * Admin resets another staff member's password (`docs/04` section 32,
 * `DL-17` (8)): a new temporary password, the gate set again, and every token
 * of the account deleted and its push devices revoked, because a reset is
 * what an Admin does when the holder of the old sessions can no longer be
 * trusted (`DL-26` (5)). A blocked account may
 * be reset too, ready for its unblocking.
 *
 * An Admin's own password is changed with `POST /auth/change-password`; a
 * reset of oneself would end the very session that asked for it
 * (`409 self_reset_not_allowed`, `DL-25`).
 */
final class ResetStaffPassword
{
    public function __invoke(User $admin, string $staffId): TemporaryCredentials
    {
        return DB::transaction(function () use ($admin, $staffId): TemporaryCredentials {
            $staff = ScopedLookup::lockOrNotFound(StaffDirectory::staff()->whereKey($staffId));

            if ($staff->is($admin)) {
                throw ApiException::conflict('self_reset_not_allowed');
            }

            $password = TemporaryPassword::generate();

            $staff->forceFill([
                'password' => $password,
                'must_change_password' => true,
                'password_changed_at' => null,
            ])->save();

            $staff->tokens()->delete();
            RevokePushDevice::everyDeviceOf($staff);

            return new TemporaryCredentials($staff, $password);
        });
    }
}
