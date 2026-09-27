<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Enums\SubstitutionPolicy;
use App\Models\Product;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Builds a cart line: one kilogram of a new product, with the default rule
 * (`BR-CART-004`).
 *
 * @extends Factory<CartItem>
 */
final class CartItemFactory extends Factory
{
    protected $model = CartItem::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'cart_id' => Cart::factory(),
            'product_id' => Product::factory(),
            'quantity' => '1.000',
            'customer_note' => null,
            'substitution_policy' => SubstitutionPolicy::AllowSimilar,
        ];
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function newModel(array $attributes = []): CartItem
    {
        return (new CartItem)->forceFill($attributes);
    }
}
