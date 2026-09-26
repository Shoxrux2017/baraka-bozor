<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Product;
use App\Models\ProductImage;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * Builds image metadata the database will accept. It writes no bytes to any
 * disk; a test that needs the file uses the fake storage of the image task.
 *
 * @extends Factory<ProductImage>
 */
final class ProductImageFactory extends Factory
{
    protected $model = ProductImage::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'product_id' => Product::factory(),
            'storage_key' => 'products/'.Str::uuid().'.webp',
            'original_filename' => 'pomidor.webp',
            'mime_type' => 'image/webp',
            'size_bytes' => 120_000,
        ];
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function newModel(array $attributes = []): ProductImage
    {
        return (new ProductImage)->forceFill($attributes);
    }
}
