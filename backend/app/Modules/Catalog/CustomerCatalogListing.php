<?php

declare(strict_types=1);

namespace App\Modules\Catalog;

use App\Models\Category;
use App\Models\Product;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Query\Builder as QueryBuilder;

/**
 * What a Customer may see of the catalog (`docs/09` section 14, `DL-22`):
 * the active, unarchived products of active, unarchived categories, and those
 * categories that hold at least one such product. A product hidden by either
 * rule does not exist for the Customer — its detail is the scope-safe `404`,
 * exactly like an id that never existed.
 *
 * Both conditions across tables are `whereExists`, not joins: the query then
 * selects one table's columns only, and a later `FOR UPDATE` over it (the
 * cart and checkout, Wave 2) locks that table's rows alone (`ScopedLookup`).
 */
final class CustomerCatalogListing
{
    /**
     * @return Builder<Category>
     */
    public static function categories(): Builder
    {
        $query = CatalogSearch::ordered(Category::query()->with('image'));

        // A category the Admin is still filling would open onto an empty
        // list, so it stays out of the Customer's list until it has a product.
        return $query
            ->where($query->qualifyColumn('is_active'), true)
            ->whereNull($query->qualifyColumn('archived_at'))
            ->whereExists(static function (QueryBuilder $product) use ($query): void {
                $product->selectRaw('1')
                    ->from('products')
                    ->whereColumn('products.category_id', $query->qualifyColumn('id'))
                    ->where('products.is_active', true)
                    ->whereNull('products.archived_at');
            });
    }

    /**
     * @return Builder<Product>
     */
    public static function products(
        ?string $categoryId,
        ?string $search,
        bool $featuredOnly = false,
        ProductSort $sort = ProductSort::Default,
    ): Builder {
        $query = CatalogSearch::matching(self::visibleProducts(), $search);

        if ($categoryId !== null) {
            $query->where($query->qualifyColumn('category_id'), $categoryId);
        }

        if ($featuredOnly) {
            $query->where($query->qualifyColumn('is_featured'), true);
        }

        // One markup applies to every product, so the market price orders the
        // customer prices too; ties keep the shop's order, which ends in `id`,
        // so pages never repeat or skip a product.
        match ($sort) {
            ProductSort::PriceAsc => $query->orderBy($query->qualifyColumn('market_price_uzs')),
            ProductSort::PriceDesc => $query->orderByDesc($query->qualifyColumn('market_price_uzs')),
            ProductSort::Default => null,
        };

        return CatalogSearch::ordered($query);
    }

    /**
     * @return Builder<Product>
     */
    public static function visibleProducts(): Builder
    {
        $query = Product::query()->with('image');

        return $query
            ->where($query->qualifyColumn('is_active'), true)
            ->whereNull($query->qualifyColumn('archived_at'))
            ->whereExists(static function (QueryBuilder $category) use ($query): void {
                $category->selectRaw('1')
                    ->from('categories')
                    ->whereColumn('categories.id', $query->qualifyColumn('category_id'))
                    ->where('categories.is_active', true)
                    ->whereNull('categories.archived_at');
            });
    }
}
