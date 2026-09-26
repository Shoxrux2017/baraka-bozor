<?php

declare(strict_types=1);

namespace App\Modules\Catalog;

use App\Models\ProductImage;
use Illuminate\Support\Facades\Storage;

/**
 * Where product images live and how they are reached (`DL-17` (5)): the
 * `public` disk, under `products/<uuid>.<ext>`, a fresh key per upload so the
 * public URL changes whenever the image does. In development the disk is
 * served from `/storage` after `php artisan storage:link`; at deployment an
 * S3-compatible disk replaces it through the same configuration.
 */
final class ProductImages
{
    public const DISK = 'public';

    public const DIRECTORY = 'products';

    /**
     * The formats `BR-CAT-004` allows, by the MIME type the bytes declare,
     * with the extension each is stored under.
     *
     * @var array<string, string>
     */
    public const EXTENSIONS = [
        'image/jpeg' => 'jpg',
        'image/png' => 'png',
        'image/webp' => 'webp',
    ];

    /** Five mebibytes, in the kilobytes Laravel's `max` rule counts. */
    public const MAX_KILOBYTES = 5 * 1024;

    public static function url(?ProductImage $image): ?string
    {
        return $image === null ? null : Storage::disk(self::DISK)->url($image->storage_key);
    }
}
