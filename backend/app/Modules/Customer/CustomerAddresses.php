<?php

declare(strict_types=1);

namespace App\Modules\Customer;

use App\Models\CustomerAddress;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;

/**
 * The addresses that exist for a Customer: their own, active ones. Another
 * Customer's address and a deactivated one are outside this scope and answer
 * the scope-safe `404` (`docs/09` section 13, `DL-17` (6)).
 */
final class CustomerAddresses
{
    /**
     * @return Builder<CustomerAddress>
     */
    public static function own(User $customer): Builder
    {
        return CustomerAddress::query()
            ->where('customer_id', $customer->id)
            ->where('is_active', true);
    }
}
