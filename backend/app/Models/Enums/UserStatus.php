<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * The account states `08` Section 3 approves.
 *
 * There is no third state. A deleted account is not one of them either: `08`
 * Section 3 forbids hard-deleting historical users, so an account that should no
 * longer be used is `Blocked`, with `blocked_at` recorded.
 */
enum UserStatus: string
{
    case Active = 'active';
    case Blocked = 'blocked';
}
