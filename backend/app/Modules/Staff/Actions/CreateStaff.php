<?php

declare(strict_types=1);

namespace App\Modules\Staff\Actions;

use App\Exceptions\ApiException;
use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\User;
use App\Modules\Staff\StaffDirectory;
use App\Modules\Staff\TemporaryCredentials;
use App\Modules\Staff\TemporaryPassword;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Support\Facades\DB;

/**
 * Admin creates a staff account (`docs/04` section 32, `BR-ROLE-004`,
 * `BR-ROLE-005`, `BR-ROLE-010`): no other active staff account may hold the
 * phone, the server generates a temporary password, and the gate is set so
 * the holder must choose their own before doing anything else.
 */
final class CreateStaff
{
    public function __invoke(User $admin, string $fullName, string $phone, Role $role): TemporaryCredentials
    {
        if (StaffDirectory::activeHolderExists($phone)) {
            throw ApiException::conflict('phone_already_active');
        }

        $password = TemporaryPassword::generate();
        $staff = new User;

        // `role`, `status`, the gate and the creator are outside `$fillable`;
        // this action is one of the few places entitled to decide them.
        $staff->forceFill([
            'role' => $role,
            'phone' => $phone,
            'full_name' => $fullName,
            'password' => $password,
            'status' => UserStatus::Active,
            'must_change_password' => true,
            'password_changed_at' => null,
            'created_by_user_id' => $admin->id,
        ]);

        try {
            // One statement, but in a transaction of its own, so a refused
            // insert inside a caller's transaction rolls back to a savepoint
            // instead of aborting the caller's work.
            DB::transaction(static fn () => $staff->save());
        } catch (UniqueConstraintViolationException $exception) {
            // Two creates for one phone at the same instant: the partial unique
            // index decides, and the loser gets the answer the check would have
            // given it.
            throw StaffDirectory::isActivePhoneClash($exception)
                ? ApiException::conflict('phone_already_active')
                : $exception;
        }

        return new TemporaryCredentials($staff->refresh(), $password);
    }
}
