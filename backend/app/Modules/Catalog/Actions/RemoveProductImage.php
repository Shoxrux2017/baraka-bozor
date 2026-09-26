<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Actions;

use App\Models\Product;
use App\Models\ProductImage;
use App\Modules\Catalog\ProductImages;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;

/**
 * Removes a product's image (`docs/09` section 16): the row in a
 * transaction with the product row locked first, like an upload, so a removal
 * and an upload for one product are decided in one order; the file after the
 * commit. A product without an image is a natural repeat.
 */
final class RemoveProductImage
{
    public function __invoke(Product $product): Product
    {
        $key = DB::transaction(function () use ($product): ?string {
            Product::query()->whereKey($product->id)->lockForUpdate()->firstOrFail();
            $image = ProductImage::query()->where('product_id', $product->id)->lockForUpdate()->first();

            if ($image === null) {
                return null;
            }

            $image->delete();

            return $image->storage_key;
        });

        if ($key !== null) {
            Storage::disk(ProductImages::DISK)->delete($key);
        }

        return $product->load('image');
    }
}
