<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * The account states `08` Section 3 approves.
 *
 * `Deleted` is a Customer account that was erased (`BR-ROLE-013`): the row stays
 * because orders, payments and history reference it, but it holds no phone and
 * no name and can never sign in again. `08` Section 3 still forbids
 * hard-deleting historical users.
 */
enum UserStatus: string
{
    case Active = 'active';
    case Blocked = 'blocked';
    case Deleted = 'deleted';
}
