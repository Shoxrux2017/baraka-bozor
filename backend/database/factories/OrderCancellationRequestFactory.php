<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\CancellationReason;
use App\Models\Enums\CancellationRequestOrigin;
use App\Models\Enums\CancellationRequestStatus;
use App\Models\Enums\ItemRemovedReason;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\OrderCancellationRequest;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Builds the Customer's pending request to cancel an order being shopped
 * (`BR-CAN-002`). The states decide it or close it, and leave the order as the
 * action does: an approved request cancels it (`DL-54` (12)); a closed one
 * found it cancelled because nothing was left to buy (`DL-54` (7)).
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
        return $this->decided(CancellationRequestStatus::Approved)->afterCreating(
            fn (OrderCancellationRequest $request) => self::cancel($request->order, CancellationReason::CancellationRequestApproved)
        );
    }

    public function rejected(): self
    {
        return $this->decided(CancellationRequestStatus::Rejected);
    }

    /**
     * Closed without a decision: the last line was removed with nothing
     * bought, which cancelled the order first (`DL-54` (7), (12)).
     */
    public function closed(): self
    {
        return $this->state(fn (): array => [
            'status' => CancellationRequestStatus::Closed,
            'resolved_at' => now(),
        ])->afterCreating(fn (OrderCancellationRequest $request) => self::cancel($request->order, CancellationReason::NoItemsPurchased));
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
     * Cancels the order the way a cancellation does: its current assignments
     * end and its open lines are removed.
     */
    private static function cancel(Order $order, CancellationReason $reason): void
    {
        $order->forceFill(['status' => OrderStatus::Cancelled, 'cancelled_at' => now(), 'cancellation_reason_code' => $reason])->save();

        foreach ([$order->shopperAssignments(), $order->courierAssignments()] as $assignments) {
            $assignments->whereNull('ended_at')->update(['ended_at' => now(), 'ended_reason' => AssignmentEndReason::OrderCancelled->value]);
        }

        $order->items()
            ->whereIn('status', [OrderItemStatus::Pending->value, OrderItemStatus::AwaitingCustomer->value])
            ->update([
                'status' => OrderItemStatus::Removed->value,
                'removed_reason_code' => ItemRemovedReason::OrderCancelled->value,
                'removed_at' => now(),
                'billable_quantity' => '0',
                'line_total_uzs' => 0,
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
