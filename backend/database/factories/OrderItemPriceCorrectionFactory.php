<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderItemPriceCorrection;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Builds an Admin's correction of an estimate line bought at 16 000 and
 * billed 18 400, to 15 000 and 17 250 under its 15 % markup, on an order
 * waiting for its Courier. The line carries the corrected price, as the
 * action leaves it; the order's final amounts are the factory's own.
 *
 * @extends Factory<OrderItemPriceCorrection>
 */
final class OrderItemPriceCorrectionFactory extends Factory
{
    protected $model = OrderItemPriceCorrection::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'order_item_id' => OrderItem::factory()
                ->for(Order::factory()->readyForDelivery())
                ->purchased()
                ->state(['actual_market_price_uzs' => 15000, 'billable_unit_price_uzs' => 17250, 'line_total_uzs' => 34500]),
            'old_actual_market_price_uzs' => 16000,
            'new_actual_market_price_uzs' => 15000,
            'old_billable_unit_price_uzs' => 18400,
            'new_billable_unit_price_uzs' => 17250,
            'corrected_by_user_id' => User::factory()->role(Role::Admin),
            'reason' => 'Опечатка в цене',
        ];
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function newModel(array $attributes = []): OrderItemPriceCorrection
    {
        return (new OrderItemPriceCorrection)->forceFill($attributes);
    }
}
