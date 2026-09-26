<?php

declare(strict_types=1);

namespace App\Modules\Staff\Actions;

use App\Exceptions\ApiException;
use App\Models\Enums\UserStatus;
use App\Models\User;
use App\Modules\Staff\StaffDirectory;
use App\Support\Scope\ScopedLookup;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;

/**
 * Admin unblocks a staff account (`docs/02` section 12, `BR-ROLE-010`):
 * refused with `409 phone_already_active` while another active staff account
 * holds the phone — the case of a role change, where the old account was
 * blocked and a new one created on the same phone (`BR-ROLE-002`). The
 * password and the gate are left as they were; the tokens went at the block.
 * Activating an active account is a natural repeat (`docs/09` section 49).
 */
final class ActivateStaff
{
    public function __invoke(string $staffId): User
    {
        return DB::transaction(function () use ($staffId): User {
            $staff = ScopedLookup::lockOrNotFound(StaffDirectory::staff()->whereKey($staffId));

            if ($staff->status === UserStatus::Active) {
                return $staff;
            }

            if (StaffDirectory::activeHolderExists($staff->phone, $staff->id)) {
                throw ApiException::conflict('phone_already_active');
            }

            try {
                $staff->forceFill([
                    'status' => UserStatus::Active,
                    'blocked_at' => null,
                ])->save();
            } catch (UniqueConstraintViolationException $exception) {
                throw StaffDirectory::isActivePhoneClash($exception)
                    ? ApiException::conflict('phone_already_active')
                    : $exception;
            }

            return $staff;
        });
    }
}
