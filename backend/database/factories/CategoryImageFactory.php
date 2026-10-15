<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Category;
use App\Models\CategoryImage;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Support\Str;

/**
 * Builds image metadata the database will accept. It writes no bytes to any
 * disk; a test that needs the file uses the fake storage of the image task.
 *
 * @extends Factory<CategoryImage>
 */
final class CategoryImageFactory extends Factory
{
    protected $model = CategoryImage::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'category_id' => Category::factory(),
            'storage_key' => 'categories/'.Str::uuid().'.webp',
            'original_filename' => 'sabzavotlar.webp',
            'mime_type' => 'image/webp',
            'size_bytes' => 120_000,
        ];
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function newModel(array $attributes = []): CategoryImage
    {
        return (new CategoryImage)->forceFill($attributes);
    }
}
