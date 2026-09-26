<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Actions;

use App\Exceptions\ApiException;
use App\Models\Category;
use App\Models\Product;
use App\Models\User;

/**
 * Creates and updates categories and products from a validated body.
 *
 * `is_active` is assigned here rather than filled (`DL-18` (2)): hiding is
 * part of the write body, but an archived entry is never active, and asking
 * for that is a `409 business_conflict` rather than a database error. The
 * creator is the authenticated Admin.
 */
final class SaveCatalogEntry
{
    /**
     * @param  array<string, mixed>  $fields
     */
    public function createCategory(User $admin, array $fields): Category
    {
        $category = new Category;

        return $this->save($category, $fields, $admin);
    }

    /**
     * @param  array<string, mixed>  $fields
     */
    public function createProduct(User $admin, array $fields): Product
    {
        $product = new Product;

        return $this->save($product, $fields, $admin);
    }

    /**
     * @template TEntry of Category|Product
     *
     * @param  TEntry  $entry
     * @param  array<string, mixed>  $fields
     * @return TEntry
     */
    public function update(Category|Product $entry, array $fields): Category|Product
    {
        return $this->save($entry, $fields, null);
    }

    /**
     * @template TEntry of Category|Product
     *
     * @param  TEntry  $entry
     * @param  array<string, mixed>  $fields
     * @return TEntry
     */
    private function save(Category|Product $entry, array $fields, ?User $creator): Category|Product
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

        if ($creator !== null) {
            $entry->created_by_user_id = $creator->id;
        }

        $entry->save();

        return $entry->refresh();
    }
}
