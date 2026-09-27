<?php

declare(strict_types=1);

namespace App\Modules\Orders\Operations;

use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Query\Builder as QueryBuilder;

/**
 * The Shoppers an Operator may assign (`docs/09` section 39, `DL-37` (11)):
 * active Shopper accounts, each with `current_assignment_count` — the orders
 * in its hands now — ordered by name regardless of case, then by id, so the
 * pages are deterministic.
 */
final class ShopperPicker
{
    /**
     * @return Builder<User>
     */
    public static function shoppers(): Builder
    {
        return User::query()
            ->where('users.role', Role::Shopper->value)
            ->where('users.status', UserStatus::Active->value)
            ->select('users.*')
            ->selectSub(static fn (QueryBuilder $assignments) => $assignments->from('order_shopper_assignments')
                ->selectRaw('count(*)')
                ->whereColumn('order_shopper_assignments.shopper_id', 'users.id')
                ->whereNull('order_shopper_assignments.ended_at'), 'current_assignment_count')
            ->orderByRaw('lower(users.full_name)')
            ->orderBy('users.id');
    }
}
