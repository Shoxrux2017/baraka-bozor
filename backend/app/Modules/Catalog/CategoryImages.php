<?php

declare(strict_types=1);

namespace App\Modules\Catalog;

use App\Models\CategoryImage;
use Illuminate\Support\Facades\Storage;

/**
 * Where category pictures live (`DL-79` (2)): the same `public` disk and the
 * same formats as product images, under `categories/<uuid>.<ext>`, a fresh key
 * per upload.
 */
final class CategoryImages
{
    public const DIR = 'categories';

    public static function url(?CategoryImage $image): ?string
    {
        return $image === null ? null : Storage::disk(ProductImages::DISK)->url($image->storage_key);
    }
}
