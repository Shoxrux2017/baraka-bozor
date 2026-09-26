<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Actions;

use App\Models\Category;
use App\Models\Product;
use App\Support\Scope\ScopedLookup;
use Illuminate\Support\Facades\DB;

/**
 * Archive and restore for categories and products (`docs/09` section 15,
 * `DL-17` (14)): archiving sets `archived_at` and clears `is_active`, restoring
 * clears `archived_at` and sets `is_active` back to true. Both are natural
 * repeats (`docs/09` section 49). Each runs on the row locked, so it is
 * serialized against an edit of the same entry.
 *
 * Archiving a category does not archive its products; the Customer catalog
 * hides the products of an inactive category by its own query.
 */
final class CatalogArchive
{
    public function archiveCategory(Category $category): Category
    {
        return DB::transaction(fn (): Category => $this->archive(
            ScopedLookup::lockOrNotFound(Category::query()->whereKey($category->id))
        ));
    }

    public function restoreCategory(Category $category): Category
    {
        return DB::transaction(fn (): Category => $this->restore(
            ScopedLookup::lockOrNotFound(Category::query()->whereKey($category->id))
        ));
    }

    public function archiveProduct(Product $product): Product
    {
        return DB::transaction(fn (): Product => $this->archive(
            ScopedLookup::lockOrNotFound(Product::query()->whereKey($product->id))
        ));
    }

    public function restoreProduct(Product $product): Product
    {
        return DB::transaction(fn (): Product => $this->restore(
            ScopedLookup::lockOrNotFound(Product::query()->whereKey($product->id))
        ));
    }

    /**
     * @template TEntry of Category|Product
     *
     * @param  TEntry  $entry
     * @return TEntry
     */
    private function archive(Category|Product $entry): Category|Product
    {
        if ($entry->archived_at === null) {
            $entry->archived_at = now();
            $entry->is_active = false;
            $entry->save();
        }

        return $entry;
    }

    /**
     * @template TEntry of Category|Product
     *
     * @param  TEntry  $entry
     * @return TEntry
     */
    private function restore(Category|Product $entry): Category|Product
    {
        if ($entry->archived_at !== null) {
            $entry->archived_at = null;
            $entry->is_active = true;
            $entry->save();
        }

        return $entry;
    }
}
