<?php

declare(strict_types=1);

namespace App\Modules\Staff\Actions;

use App\Exceptions\ApiException;
use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\User;
use App\Modules\Staff\StaffDirectory;
use App\Support\Scope\ScopedLookup;
use Illuminate\Support\Facades\DB;

/**
 * Admin blocks a staff account (`docs/02` section 12, `BR-ROLE-007`,
 * `BR-ROLE-008`): never their own, never the last active Admin, and every
 * token of the account is deleted at the same moment, so an old session
 * stops working with its next request. Blocking a blocked account is a
 * natural repeat (`docs/09` section 49): the current account, nothing changed.
 *
 * Lock order. When the target is an Admin, every active Admin row is locked
 * first, in id order, and the target after; two Admins blocking each other at
 * once therefore queue on the same rows instead of deadlocking, and the second
 * sees the first one's block and is refused as the last active Admin. The
 * role is read before any lock because it never changes (`BR-ROLE-002`).
 */
final class BlockStaff
{
    public function __invoke(User $admin, string $staffId): User
    {
        $role = ScopedLookup::firstOrNotFound(StaffDirectory::staff()->whereKey($staffId))->role;

        return DB::transaction(function () use ($admin, $staffId, $role): User {
            $activeAdminIds = $role === Role::Admin
                ? User::query()
                    ->where('role', Role::Admin->value)
                    ->where('status', UserStatus::Active->value)
                    ->orderBy('id')
                    ->lockForUpdate()
                    ->pluck('id')
                    ->all()
                : [];

            $staff = ScopedLookup::lockOrNotFound(StaffDirectory::staff()->whereKey($staffId));

            if ($staff->is($admin)) {
                throw ApiException::conflict('self_block_not_allowed');
            }

            if ($staff->status === UserStatus::Blocked) {
                return $staff;
            }

            if ($role === Role::Admin && array_diff($activeAdminIds, [$staff->id]) === []) {
                throw ApiException::conflict('last_active_admin_required');
            }

            $staff->forceFill([
                'status' => UserStatus::Blocked,
                'blocked_at' => now(),
            ])->save();

            $staff->tokens()->delete();

            return $staff;
        });
    }
}
