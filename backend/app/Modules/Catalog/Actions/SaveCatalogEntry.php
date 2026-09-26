<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Actions;

use App\Exceptions\ApiException;
use App\Models\Category;
use App\Models\Product;
use App\Models\User;
use App\Support\Scope\ScopedLookup;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * Creates and updates categories and products from a validated body.
 *
 * `is_active` is assigned here rather than filled (`DL-18` (2)): hiding is
 * part of the write body, but an archived entry is never active, and asking
 * for that is a `409 business_conflict`. A product goes into, or moves to,
 * an existing unarchived category only; a product already in an archived
 * category keeps it when an edit re-sends it unchanged.
 *
 * Every write runs in a transaction with the entry locked and, for a
 * product, its target category share-locked, so an archive committing at the
 * same moment is decided in one order or the other — never a database check
 * failing into a `500` (`backend/AGENTS.md` section 8). Lock order: the entry,
 * then the category.
 */
final class SaveCatalogEntry
{
    /**
     * @param  array<string, mixed>  $fields
     */
    public function createCategory(User $admin, array $fields): Category
    {
        return DB::transaction(function () use ($admin, $fields): Category {
            $category = new Category;
            $category->created_by_user_id = $admin->id;

            return $this->apply($category, $fields);
        });
    }

    /**
     * @param  array<string, mixed>  $fields
     */
    public function createProduct(User $admin, array $fields): Product
    {
        return DB::transaction(function () use ($admin, $fields): Product {
            $this->assertCategoryOpen((string) $fields['category_id']);

            $product = new Product;
            $product->created_by_user_id = $admin->id;

            return $this->apply($product, $fields);
        });
    }

    /**
     * @param  array<string, mixed>  $fields
     */
    public function updateCategory(Category $category, array $fields): Category
    {
        return DB::transaction(function () use ($category, $fields): Category {
            $locked = ScopedLookup::lockOrNotFound(Category::query()->whereKey($category->id));

            return $this->apply($locked, $fields);
        });
    }

    /**
     * @param  array<string, mixed>  $fields
     */
    public function updateProduct(Product $product, array $fields): Product
    {
        return DB::transaction(function () use ($product, $fields): Product {
            $locked = ScopedLookup::lockOrNotFound(Product::query()->whereKey($product->id));

            $target = $fields['category_id'] ?? null;
            if (is_string($target) && strcasecmp($target, $locked->category_id) !== 0) {
                $this->assertCategoryOpen($target);
            }

            return $this->apply($locked, $fields);
        });
    }

    /**
     * @template TEntry of Category|Product
     *
     * @param  TEntry  $entry
     * @param  array<string, mixed>  $fields
     * @return TEntry
     */
    private function apply(Category|Product $entry, array $fields): Category|Product
    {
        $active = array_key_exists('is_active', $fields) ? (bool) $fields['is_active'] : null;
        unset($fields['is_active']);

        if ($active === true && $entry->archived_at !== null) {
            throw ApiException::conflict('business_conflict', [], 'An archived entry cannot be made active; restore it instead.');
        }

        $entry->fill($fields);

        if ($active !== null) {
            $entry->is_active = $active;
        }

        $entry->save();

        return $entry->refresh();
    }

    /**
     * The category exists and is not archived, and stays so until this
     * transaction ends.
     */
    private function assertCategoryOpen(string $categoryId): void
    {
        $category = Category::query()->whereKey($categoryId)->sharedLock()->first();

        if ($category === null || $category->archived_at !== null) {
            throw ValidationException::withMessages([
                'category_id' => 'The category does not exist or is archived.',
            ]);
        }
    }
}
