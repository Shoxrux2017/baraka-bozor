<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Actions;

use App\Models\Category;
use App\Models\Product;

/**
 * Archive and restore for categories and products (`docs/09` section 15,
 * `DL-17` (14)): archiving sets `archived_at` and clears `is_active`, restoring
 * clears `archived_at` and sets `is_active` back to true. Both are natural
 * repeats (`docs/09` section 49): archiving an archived entry or restoring an
 * active one returns it unchanged.
 *
 * Archiving a category does not archive its products; the Customer catalog
 * hides the products of an inactive category by its own query.
 */
final class CatalogArchive
{
    public function archive(Category|Product $entry): Category|Product
    {
        if ($entry->archived_at !== null) {
            return $entry;
        }

        $entry->archived_at = now();
        $entry->is_active = false;
        $entry->save();

        return $entry;
    }

    public function restore(Category|Product $entry): Category|Product
    {
        if ($entry->archived_at === null) {
            return $entry;
        }

        $entry->archived_at = null;
        $entry->is_active = true;
        $entry->save();

        return $entry;
    }
}
