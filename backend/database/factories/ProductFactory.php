<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Category;
use App\Models\Enums\PriceMode;
use App\Models\Enums\Role;
use App\Models\Enums\UnitCode;
use App\Models\Product;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Builds products the database will accept, in a category created on demand.
 *
 * The default is an estimate-priced kilogram product, the case with the most
 * behaviour (tolerance, approvals, decimal quantities); a test about the
 * simpler fixed case says so with [fixed].
 *
 * @extends Factory<Product>
 */
final class ProductFactory extends Factory
{
    protected $model = Product::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'category_id' => Category::factory(),
            'name_uz' => 'Pomidor '.fake()->unique()->numberBetween(1, 100000),
            'name_ru' => 'Помидор '.fake()->numberBetween(1, 100000),
            'description_uz' => null,
            'description_ru' => null,
            'unit_code' => UnitCode::Kg,
            'price_mode' => PriceMode::Estimate,
            'market_price_uzs' => 16000,
            'is_active' => true,
            'sort_order' => 0,
            'archived_at' => null,
            'created_by_user_id' => User::factory()->role(Role::Admin),
        ];
    }

    public function fixed(): self
    {
        return $this->state(fn (): array => ['price_mode' => PriceMode::Fixed]);
    }

    public function unit(UnitCode $unit): self
    {
        return $this->state(fn (): array => ['unit_code' => $unit]);
    }

    public function archived(): self
    {
        return $this->state(fn (): array => [
            'is_active' => false,
            'archived_at' => now(),
        ]);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function newModel(array $attributes = []): Product
    {
        return (new Product)->forceFill($attributes);
    }
}
