<?php

declare(strict_types=1);

namespace App\Modules\Customer;

use App\Models\CustomerFavorite;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;

/**
 * A Customer's own favourites (`docs/09` section 58, `BR-CAT-007`). Another
 * Customer's rows are outside this scope.
 */
final class CustomerFavorites
{
    public const LIMIT = 500;

    /**
     * @return Builder<CustomerFavorite>
     */
    public static function own(User $customer): Builder
    {
        return CustomerFavorite::query()->where('customer_id', $customer->id);
    }
}
