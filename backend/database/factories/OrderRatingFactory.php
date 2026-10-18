<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Enums\RatingReason;
use App\Models\Order;
use App\Models\OrderRating;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Builds the rating of a delivered order: five stars by default, `low()` a
 * 2-star one with a reason (`BR-RATE-002`).
 *
 * @extends Factory<OrderRating>
 */
final class OrderRatingFactory extends Factory
{
    protected $model = OrderRating::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'order_id' => Order::factory()->completed(),
            'customer_id' => fn (array $attributes): string => Order::query()->findOrFail($attributes['order_id'])->customer_id,
            'stars' => 5,
            'reasons' => [],
            'comment' => null,
            'reviewed_by_user_id' => null,
            'reviewed_at' => null,
        ];
    }

    public function low(int $stars = 2): self
    {
        return $this->state(fn (): array => ['stars' => $stars, 'reasons' => [RatingReason::NotFresh->value]]);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function newModel(array $attributes = []): OrderRating
    {
        return (new OrderRating)->forceFill($attributes);
    }
}
