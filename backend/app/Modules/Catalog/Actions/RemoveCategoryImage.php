<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Actions;

use App\Models\Category;
use App\Models\CategoryImage;
use App\Modules\Catalog\ProductImages;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

/**
 * Removes a category's picture (`docs/09` section 16, `DL-79` (2)): the row in
 * a transaction with the category row locked first, like an upload, the file
 * after the commit. A category without a picture is a natural repeat.
 */
final class RemoveCategoryImage
{
    public function __invoke(Category $category): Category
    {
        $key = DB::transaction(function () use ($category): ?string {
            Category::query()->whereKey($category->id)->lockForUpdate()->firstOrFail();
            $image = CategoryImage::query()->where('category_id', $category->id)->lockForUpdate()->first();

            if ($image === null) {
                return null;
            }

            $image->delete();

            return $image->storage_key;
        });

        if ($key !== null) {
            Storage::disk(ProductImages::DISK)->delete($key);
        }

        return $category->load('image');
    }
}
