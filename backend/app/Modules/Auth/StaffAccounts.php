<?php

declare(strict_types=1);

namespace App\Modules\Auth;

use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\User;

/**
 * Which Staff account a phone currently stands for: the active non-Customer
 * account, else the most recently blocked one. Used by both the password login
 * and the code verification, so the two never disagree about the account.
 */
final class StaffAccounts
{
    public static function currentFor(string $phone): ?User
    {
        return self::active($phone) ?? self::blocked($phone);
    }

    private static function active(string $phone): ?User
    {
        return User::query()
            ->where('phone', $phone)
            ->where('role', '<>', Role::Customer->value)
            ->where('status', UserStatus::Active->value)
            ->first();
    }

    private static function blocked(string $phone): ?User
    {
        return User::query()
            ->where('phone', $phone)
            ->where('role', '<>', Role::Customer->value)
            ->where('status', UserStatus::Blocked->value)
            ->orderByDesc('blocked_at')
            ->first();
    }
}
