<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Enums\CancellationRequestOrigin;
use App\Models\Enums\CancellationRequestStatus;
use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\OrderCancellationRequest;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Builds the Customer's pending request to cancel an order being shopped
 * (`BR-CAN-002`); the states decide it or close it.
 *
 * @extends Factory<OrderCancellationRequest>
 */
final class OrderCancellationRequestFactory extends Factory
{
    protected $model = OrderCancellationRequest::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'order_id' => Order::factory()->shopping(),
            'origin' => CancellationRequestOrigin::Customer,
            'requested_by_user_id' => fn (array $attributes): string => Order::query()->findOrFail($attributes['order_id'])->customer_id,
            'status' => CancellationRequestStatus::Pending,
            'reason' => 'Планы изменились',
            'resolved_by_user_id' => null,
            'resolution_note' => null,
            'resolved_at' => null,
        ];
    }

    public function approved(): self
    {
        return $this->decided(CancellationRequestStatus::Approved);
    }

    public function rejected(): self
    {
        return $this->decided(CancellationRequestStatus::Rejected);
    }

    /**
     * Closed without a decision: the order was cancelled another way first
     * (`DL-54` (12)).
     */
    public function closed(): self
    {
        return $this->state(fn (): array => [
            'status' => CancellationRequestStatus::Closed,
            'resolved_at' => now(),
        ]);
    }

    private function decided(CancellationRequestStatus $status): self
    {
        return $this->state(fn (): array => [
            'status' => $status,
            'resolved_by_user_id' => User::factory()->role(Role::Operator),
            'resolved_at' => now(),
        ]);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function newModel(array $attributes = []): OrderCancellationRequest
    {
        return (new OrderCancellationRequest)->forceFill($attributes);
    }
}
