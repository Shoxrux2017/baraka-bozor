<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\OrderShopperAssignment;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Builds a current Shopper assignment made by an Operator, on an order that
 * is `shopping_assigned` as a current assignment implies; the states walk it
 * through acceptance, the start of shopping and its end.
 *
 * @extends Factory<OrderShopperAssignment>
 */
final class OrderShopperAssignmentFactory extends Factory
{
    protected $model = OrderShopperAssignment::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'order_id' => Order::factory()->state(['status' => OrderStatus::ShoppingAssigned]),
            'shopper_id' => User::factory()->role(Role::Shopper),
            'assigned_by_user_id' => User::factory()->role(Role::Operator),
            'is_self_order' => false,
            'assigned_at' => now(),
            'accepted_at' => null,
            'started_at' => null,
            'completed_at' => null,
            'ended_at' => null,
            'ended_reason' => null,
        ];
    }

    public function accepted(): self
    {
        return $this->state(fn (): array => ['accepted_at' => now()]);
    }

    public function started(): self
    {
        return $this->state(fn (): array => ['accepted_at' => now(), 'started_at' => now()]);
    }

    /**
     * Ended for a reason: `completed` also records that shopping was done.
     */
    public function ended(AssignmentEndReason $reason): self
    {
        return $this->state(fn (): array => $reason === AssignmentEndReason::Completed
            ? [
                'accepted_at' => now(),
                'started_at' => now(),
                'completed_at' => now(),
                'ended_at' => now(),
                'ended_reason' => $reason,
            ]
            : ['ended_at' => now(), 'ended_reason' => $reason]);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function newModel(array $attributes = []): OrderShopperAssignment
    {
        return (new OrderShopperAssignment)->forceFill($attributes);
    }
}
