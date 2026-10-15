<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Actions;

use App\Exceptions\ApiException;
use App\Models\Category;
use App\Models\CategoryImage;
use App\Modules\Catalog\CategoryImages;
use App\Modules\Catalog\ProductImages;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use RuntimeException;
use Throwable;

/**
 * Replaces a category's one picture (`docs/09` section 16, `BR-CAT-004`,
 * `DL-79` (2)), exactly as `ReplaceProductImage` does for a product: the new
 * file first under a fresh key, then one transaction with the category row
 * locked first and the image row second, the previous file removed only after
 * the commit, and the new file removed again on any failure before it.
 * Archived categories accept a picture too.
 */
final class ReplaceCategoryImage
{
    public function __invoke(Category $category, UploadedFile $file, string $mimeType): Category
    {
        $disk = Storage::disk(ProductImages::DISK);
        $name = Str::uuid()->toString().'.'.ProductImages::EXTENSIONS[$mimeType];
        $key = CategoryImages::DIR.'/'.$name;

        if ($disk->putFileAs(CategoryImages::DIR, $file, $name) === false) {
            throw new RuntimeException('The category image could not be written to storage.');
        }

        try {
            $previousKey = DB::transaction(function () use ($category, $file, $mimeType, $key): ?string {
                Category::query()->whereKey($category->id)->lockForUpdate()->firstOrFail();
                $image = CategoryImage::query()->where('category_id', $category->id)->lockForUpdate()->first();
                $previous = $image?->storage_key;

                $image ??= (new CategoryImage)->forceFill(['category_id' => $category->id]);
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

            throw ApiException::conflict('business_conflict', [], 'Another upload for this category won the race; try again.');
        } catch (Throwable $exception) {
            $disk->delete($key);

            throw $exception;
        }

        if ($previousKey !== null) {
            $disk->delete($previousKey);
        }

        return $category->load('image');
    }
}
