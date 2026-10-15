<?php

declare(strict_types=1);

namespace App\Modules\Customer\Actions;

use App\Exceptions\ApiException;
use App\Models\CustomerFavorite;
use App\Models\User;
use App\Modules\Catalog\CustomerCatalogListing;
use App\Modules\Customer\CustomerFavorites;
use App\Support\Scope\ScopedLookup;
use Illuminate\Support\Facades\DB;

/**
 * Adds and removes a Customer's favourites (`docs/09` section 58,
 * `BR-CAT-007`, `DL-79` (5)). An add needs a product the Customer can see;
 * a removal tells nothing about the product.
 */
final class ChangeFavorites
{
    public function add(User $customer, string $productId): void
    {
        DB::transaction(function () use ($customer, $productId): void {
            // One customer's adds are serialized, so the limit holds under
            // concurrent requests.
            User::query()->whereKey($customer->id)->lockForUpdate()->firstOrFail();
            ScopedLookup::firstOrNotFound(CustomerCatalogListing::visibleProducts()->whereKey($productId));

            if (CustomerFavorites::own($customer)->where('product_id', $productId)->exists()) {
                return;
            }
            if (CustomerFavorites::own($customer)->count() >= CustomerFavorites::LIMIT) {
                throw ApiException::conflict('favorites_full', ['limit' => CustomerFavorites::LIMIT]);
            }
            CustomerFavorite::query()->create(['customer_id' => $customer->id, 'product_id' => $productId]);
        });
    }

    public function remove(User $customer, string $productId): void
    {
        CustomerFavorites::own($customer)->where('product_id', $productId)->delete();
    }
}
