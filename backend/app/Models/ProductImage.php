<?php

declare(strict_types=1);

namespace App\Models;

use Database\Factories\ProductImageFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * The metadata of a product's one current image (`08` Section 8). The bytes
 * are on the filesystem disk under `storage_key`; the image task owns the
 * upload, the replacement and the public URL.
 *
 * Nothing is fillable: an image row is written whole by the upload action,
 * never from a request body.
 *
 * @property string $id
 * @property string $product_id
 * @property string $storage_key
 * @property string|null $original_filename
 * @property string $mime_type
 * @property int $size_bytes
 * @property Carbon $created_at
 * @property Carbon $updated_at
 */
class ProductImage extends Model
{
    /** @use HasFactory<ProductImageFactory> */
    use HasFactory;

    use HasUuids;

    /**
     * @var list<string>
     */
    protected $fillable = [];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'size_bytes' => 'integer',
        ];
    }

    /**
     * @return BelongsTo<Product, $this>
     */
    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }
}
