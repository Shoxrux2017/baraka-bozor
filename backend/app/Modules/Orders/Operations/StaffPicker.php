<?php

declare(strict_types=1);

namespace App\Modules\Orders\Operations;

use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Query\Builder as QueryBuilder;
use InvalidArgumentException;

/**
 * The Shoppers or the Couriers an Operator may assign (`docs/09` section 39,
 * `DL-37` (11), `DL-54` (10)): active accounts of the role, each with
 * `current_assignment_count` — the orders in its hands now — ordered by name
 * regardless of case, then by id, so the pages are deterministic.
 */
final class StaffPicker
{
    /**
     * @return Builder<User>
     */
    public static function of(Role $role): Builder
    {
        [$assignments, $assignee] = match ($role) {
            Role::Shopper => ['order_shopper_assignments', 'shopper_id'],
            Role::Courier => ['order_courier_assignments', 'courier_id'],
            default => throw new InvalidArgumentException("No one assigns a {$role->value}."),
        };

        return User::query()
            ->where('users.role', $role->value)
            ->where('users.status', UserStatus::Active->value)
            ->select('users.*')
            ->selectSub(static fn (QueryBuilder $current) => $current->from($assignments)
                ->selectRaw('count(*)')
                ->whereColumn("{$assignments}.{$assignee}", 'users.id')
                ->whereNull("{$assignments}.ended_at"), 'current_assignment_count')
            ->orderByRaw('lower(users.full_name)')
            ->orderBy('users.id');
    }
}
