<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Actions;

use App\Models\Product;
use App\Models\ProductImage;
use App\Modules\Catalog\ProductImages;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Throwable;

/**
 * Replaces a product's one image (`docs/09` section 16, `BR-CAT-004`).
 *
 * The new file is written first under a fresh key; then, in one transaction
 * with the image row locked, the row is pointed at it; only after the commit
 * is the previous file removed. A failure before the commit removes the new
 * file and leaves the old image in place, so a product is never left with a
 * row pointing at a missing file. Archived products accept an image too — an
 * Admin may prepare one before restoring the product.
 */
final class ReplaceProductImage
{
    public function __invoke(Product $product, UploadedFile $file, string $mimeType): Product
    {
        $disk = Storage::disk(ProductImages::DISK);
        $name = Str::uuid()->toString().'.'.ProductImages::EXTENSIONS[$mimeType];
        $key = ProductImages::DIRECTORY.'/'.$name;

        $disk->putFileAs(ProductImages::DIRECTORY, $file, $name);

        try {
            $previousKey = DB::transaction(function () use ($product, $file, $mimeType, $key): ?string {
                $image = ProductImage::query()->where('product_id', $product->id)->lockForUpdate()->first();
                $previous = $image?->storage_key;

                $image ??= (new ProductImage)->forceFill(['product_id' => $product->id]);
                $image->forceFill([
                    'storage_key' => $key,
                    'original_filename' => mb_substr($file->getClientOriginalName(), 0, 255),
                    'mime_type' => $mimeType,
                    'size_bytes' => (int) $file->getSize(),
                ])->save();

                return $previous;
            });
        } catch (Throwable $exception) {
            $disk->delete($key);

            throw $exception;
        }

        if ($previousKey !== null) {
            $disk->delete($previousKey);
        }

        return $product->load('image');
    }
}
