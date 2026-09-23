<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * The six roles `BR-ROLE-001` approves, and no others.
 *
 * Backed by the exact strings the `users_role_check` constraint lists, so the
 * enum and the database cannot drift apart without a migration saying so. A
 * seventh case added here would be rejected by PostgreSQL on the first save,
 * which is the intended order: the role set is the Project Owner's to change.
 */
enum Role: string
{
    case Customer = 'customer';
    case Shopper = 'shopper';
    case Courier = 'courier';
    case Operator = 'operator';
    case Admin = 'admin';
    case Manager = 'manager';

    /**
     * Whether this role belongs to the Staff account family.
     *
     * The two families differ structurally rather than by policy: a Customer
     * signs in by OTP and holds no password, Staff sign in by phone and password
     * and must hold one. `users_password_by_family_check` enforces it, and the
     * partial unique indexes on `phone` are keyed on the same split.
     */
    public function isStaff(): bool
    {
        return $this !== self::Customer;
    }
}
