<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Actions;

use App\Exceptions\ApiException;
use App\Models\Product;
use App\Models\ProductImage;
use App\Modules\Catalog\ProductImages;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RuntimeException;
use Throwable;

/**
 * Replaces a product's one image (`docs/09` section 16, `BR-CAT-004`).
 *
 * The new file is written first under a fresh key, and a write the disk
 * reports as failed stops everything before the database is touched — the
 * disks are configured not to throw, so the return value is the only signal.
 * Then, in one transaction with the product row locked first and the image
 * row second, the row is pointed at the new file; only after the commit is
 * the previous file removed. The product lock serializes two uploads for one
 * product even when it has no image row yet to lock, and a unique violation
 * that still slips through is a `409 business_conflict`, never a `500`. Any
 * failure before the commit removes the new file and leaves the old image in
 * place, so a row never points at a missing file. Archived products accept
 * an image too — an Admin may prepare one before restoring the product.
 */
final class ReplaceProductImage
{
    public function __invoke(Product $product, UploadedFile $file, string $mimeType): Product
    {
        $disk = Storage::disk(ProductImages::DISK);
        $name = Str::uuid()->toString().'.'.ProductImages::EXTENSIONS[$mimeType];
        $key = ProductImages::DIRECTORY.'/'.$name;

        if ($disk->putFileAs(ProductImages::DIRECTORY, $file, $name) === false) {
            throw new RuntimeException('The product image could not be written to storage.');
        }

        try {
            $previousKey = DB::transaction(function () use ($product, $file, $mimeType, $key): ?string {
                Product::query()->whereKey($product->id)->lockForUpdate()->firstOrFail();
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
        } catch (UniqueConstraintViolationException) {
            $disk->delete($key);

            throw ApiException::conflict('business_conflict', [], 'Another upload for this product won the race; try again.');
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
