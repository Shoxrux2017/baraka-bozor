<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\DeliveryFailureReason;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\OrderCourierAssignment;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Builds a current Courier assignment made by an Operator, on a shopped order
 * that is `delivery_assigned` as a current assignment implies; the states
 * walk it through acceptance, the start of the delivery — late an hour later,
 * the default threshold — and its end.
 *
 * @extends Factory<OrderCourierAssignment>
 */
final class OrderCourierAssignmentFactory extends Factory
{
    protected $model = OrderCourierAssignment::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'order_id' => Order::factory()->readyForDelivery()->state(['status' => OrderStatus::DeliveryAssigned]),
            'courier_id' => User::factory()->role(Role::Courier),
            'assigned_by_user_id' => User::factory()->role(Role::Operator),
            'is_self_order' => false,
            'assigned_at' => now(),
            'accepted_at' => null,
            'delivery_started_at' => null,
            'delay_at' => null,
            'completed_at' => null,
            'ended_at' => null,
            'ended_reason' => null,
            'failed_reason_code' => null,
            'failed_note' => null,
        ];
    }

    public function accepted(): self
    {
        return $this->state(fn (): array => ['accepted_at' => now()]);
    }

    public function started(): self
    {
        return $this->state(fn (): array => [
            'accepted_at' => now(),
            'delivery_started_at' => now(),
            'delay_at' => now()->addHour(),
        ]);
    }

    /**
     * Ended for a reason: `completed` also records the delivery, and
     * `delivery_failed` a delivery that set off and nobody answered.
     */
    public function ended(AssignmentEndReason $reason): self
    {
        return $this->state(fn (): array => match ($reason) {
            AssignmentEndReason::Completed => [
                'accepted_at' => now(),
                'delivery_started_at' => now(),
                'delay_at' => now()->addHour(),
                'completed_at' => now(),
                'ended_at' => now(),
                'ended_reason' => $reason,
            ],
            AssignmentEndReason::DeliveryFailed => [
                'accepted_at' => now(),
                'delivery_started_at' => now(),
                'delay_at' => now()->addHour(),
                'ended_at' => now(),
                'ended_reason' => $reason,
                'failed_reason_code' => DeliveryFailureReason::NoAnswer,
            ],
            default => ['ended_at' => now(), 'ended_reason' => $reason],
        });
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function newModel(array $attributes = []): OrderCourierAssignment
    {
        return (new OrderCourierAssignment)->forceFill($attributes);
    }
}
