<?php

declare(strict_types=1);

namespace App\Modules\Catalog;

use App\Models\Category;
use App\Models\Product;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Query\Builder as QueryBuilder;

/**
 * What a Customer may see of the catalog (`docs/09` section 14,
 * `BR-CAT-003`): active, unarchived categories, and the active, unarchived
 * products of such categories. A product hidden by either rule does not
 * exist for the Customer — its detail is the scope-safe `404`, exactly like
 * an id that never existed.
 */
final class CustomerCatalogListing
{
    /**
     * @return Builder<Category>
     */
    public static function categories(): Builder
    {
        $query = CatalogSearch::ordered(Category::query());

        return $query
            ->where($query->qualifyColumn('is_active'), true)
            ->whereNull($query->qualifyColumn('archived_at'));
    }

    /**
     * @return Builder<Product>
     */
    public static function products(?string $categoryId, ?string $search): Builder
    {
        $query = CatalogSearch::ordered(CatalogSearch::matching(self::visibleProducts(), $search));

        if ($categoryId !== null) {
            $query->where($query->qualifyColumn('category_id'), $categoryId);
        }

        return $query;
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
