<?php

declare(strict_types=1);

namespace App\Modules\Customer;

use App\Models\CustomerFavorite;
use App\Models\User;
use App\Modules\Catalog\CustomerCatalogListing;
use App\Modules\Catalog\ProductSort;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Facades\DB;

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

    /**
     * The Customer's favourites that are not sold now (`DL-129`): the product
     * is not among `CustomerCatalogListing::visibleProducts()`. One rule for
     * the flag, the order, the count and the removal.
     *
     * @return Builder<CustomerFavorite>
     */
    public static function unavailable(User $customer): Builder
    {
        return self::own($customer)->whereNotExists(self::sold());
    }

    /**
     * The list's order (`DL-129`): the sold favourites first, then the not
     * sold; inside each group the newest first, or by the product's market
     * price (one markup orders the customer prices too), ties newest first.
     * Subqueries on `product_id`, never a join that could repeat a row.
     *
     * @param  Builder<CustomerFavorite>  $query
     * @return Builder<CustomerFavorite>
     */
    public static function ordered(Builder $query, ProductSort $sort): Builder
    {
        $sold = self::sold();
        $query->orderByRaw('CASE WHEN EXISTS ('.$sold->toSql().') THEN 0 ELSE 1 END', $sold->getBindings());

        if ($sort !== ProductSort::Default) {
            $price = DB::table('products')
                ->select('market_price_uzs')
                ->whereColumn('products.id', 'customer_favorites.product_id');
            $query->orderBy($price, $sort === ProductSort::PriceAsc ? 'asc' : 'desc');
        }

        return $query->orderByDesc('customer_favorites.created_at')->orderByDesc('customer_favorites.id');
    }

    private static function sold(): QueryBuilder
    {
        return CustomerCatalogListing::visibleProducts()
            ->whereColumn('products.id', 'customer_favorites.product_id')
            ->toBase()
            ->selectRaw('1');
    }
}
