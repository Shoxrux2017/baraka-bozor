<?php

declare(strict_types=1);

namespace App\Modules\Catalog;

use App\Models\Category;
use App\Models\Product;
use Illuminate\Database\Eloquent\Builder;

/**
 * The queries behind the Admin catalog lists (`docs/09` section 15): every
 * entry, archived ones only when asked, in the catalog's order.
 */
final class AdminCatalogListing
{
    /**
     * @return Builder<Category>
     */
    public static function categories(bool $includeArchived): Builder
    {
        $query = CatalogSearch::ordered(Category::query());

        if (! $includeArchived) {
            $query->whereNull($query->qualifyColumn('archived_at'));
        }

        return $query;
    }

    /**
     * @return Builder<Product>
     */
    public static function products(bool $includeArchived, ?string $categoryId, ?string $search): Builder
    {
        $query = CatalogSearch::ordered(CatalogSearch::matching(Product::query()->with('image'), $search));

        if (! $includeArchived) {
            $query->whereNull($query->qualifyColumn('archived_at'));
        }

        if ($categoryId !== null) {
            $query->where($query->qualifyColumn('category_id'), $categoryId);
        }

        return $query;
    }
}
