<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\CustomerFavorite;
use App\Models\Product;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Builds a favourite of a new Customer for a new product.
 *
 * @extends Factory<CustomerFavorite>
 */
final class CustomerFavoriteFactory extends Factory
{
    protected $model = CustomerFavorite::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'customer_id' => User::factory()->customer(),
            'product_id' => Product::factory(),
        ];
    }
}
