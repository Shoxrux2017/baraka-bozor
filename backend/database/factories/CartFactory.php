<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Cart;
use App\Models\Enums\CartStatus;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Builds a Customer's active cart; [converted] is the cart an order came from.
 *
 * @extends Factory<Cart>
 */
final class CartFactory extends Factory
{
    protected $model = Cart::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'customer_id' => User::factory()->customer(),
            'status' => CartStatus::Active,
        ];
    }

    public function converted(): self
    {
        return $this->state(fn (): array => ['status' => CartStatus::Converted]);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function newModel(array $attributes = []): Cart
    {
        return (new Cart)->forceFill($attributes);
    }
}
