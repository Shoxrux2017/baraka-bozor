<?php

declare(strict_types=1);

namespace App\Modules\Staff;

use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\UniqueConstraintViolationException;

/**
 * The accounts staff management may see: every account but a Customer's. A
 * Customer's id is the scope-safe `404` of any staff endpoint.
 */
final class StaffDirectory
{
    /** The one-active-staff-account-per-phone index of `docs/08` section 3. */
    public const ACTIVE_PHONE_INDEX = 'users_phone_active_staff_unique';

    /**
     * @return Builder<User>
     */
    public static function staff(): Builder
    {
        $query = User::query();

        return $query->where($query->qualifyColumn('role'), '<>', Role::Customer->value);
    }

    /**
     * Whether an active staff account other than `$exceptId` holds the phone
     * (`BR-ROLE-010`).
     */
    public static function activeHolderExists(string $phone, ?string $exceptId = null): bool
    {
        return self::staff()
            ->where('phone', $phone)
            ->where('status', UserStatus::Active->value)
            ->when($exceptId !== null, fn (Builder $query) => $query->whereKeyNot($exceptId))
            ->exists();
    }

    /**
     * Whether a unique violation is that index, and not another constraint.
     */
    public static function isActivePhoneClash(UniqueConstraintViolationException $exception): bool
    {
        return str_contains($exception->getMessage(), self::ACTIVE_PHONE_INDEX);
    }
}
