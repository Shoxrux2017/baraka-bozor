<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\CustomerApproval;
use App\Models\Enums\ApprovalResolution;
use App\Models\Enums\ApprovalStatus;
use App\Models\Enums\ApprovalType;
use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\CancellationReason;
use App\Models\Enums\ItemRemovedReason;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\Role;
use App\Models\Enums\SubstitutionPolicy;
use App\Models\Enums\SubstitutionResolution;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Builds a pending price question on a line awaiting the Customer, in an order
 * being shopped, asked by that order's Shopper ten and thirty minutes before
 * its attention and expiry (`BR-APP-002`, `BR-APP-003`): 20 000 paid at the
 * stall, 23 000 to the Customer under the 15 % markup, above the estimate's
 * 21 160 ceiling.
 *
 * The states make the other questions and every resolution, and leave the
 * line and the order as the action that resolves the approval does
 * (`DL-3` S-7, `BR-APP-006`, `BR-APP-007`, `DL-54` (8)).
 *
 * @extends Factory<CustomerApproval>
 */
final class CustomerApprovalFactory extends Factory
{
    protected $model = CustomerApproval::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'order_item_id' => OrderItem::factory()->awaitingCustomer()->for(Order::factory()->shopping()),
            'order_id' => fn (array $attributes): string => $this->item($attributes)->order_id,
            'type' => ApprovalType::PriceOverTolerance,
            'status' => ApprovalStatus::Pending,
            'requested_by_user_id' => fn (array $attributes): string => $this->item($attributes)->order->currentShopperAssignment->shopper_id
                ?? User::factory()->role(Role::Shopper)->create()->id,
            'proposed_customer_unit_price_uzs' => 23000,
            'proposed_actual_market_price_uzs' => 20000,
            'proposed_quantity' => null,
            'replacement_product_id' => null,
            'replacement_name_uz_snapshot' => null,
            'replacement_name_ru_snapshot' => null,
            'replacement_unit_code_snapshot' => null,
            'request_note' => null,
            'attention_at' => now()->addMinutes(10),
            'expires_at' => now()->addMinutes(30),
            'resolved_by_user_id' => null,
            'resolved_at' => null,
            'resolution' => null,
        ];
    }

    /**
     * A replacement of the line's unit, 11 000 paid and 12 650 to the
     * Customer, on a line whose rule asks the Customer about every
     * replacement — under the default rule it would be authorized at once
     * (`docs/04` section 19).
     */
    public function substitution(): self
    {
        return $this->state(fn (): array => [
            'order_item_id' => OrderItem::factory()
                ->awaitingCustomer()
                ->for(Order::factory()->shopping())
                ->state(['substitution_policy_snapshot' => SubstitutionPolicy::ContactBefore]),
            'type' => ApprovalType::Substitution,
            'replacement_product_id' => fn (array $attributes): string => Product::factory()
                ->unit($this->item($attributes)->unit_code_snapshot)
                ->create()->id,
            'replacement_name_uz_snapshot' => fn (array $attributes): string => $this->replacement($attributes)->name_uz,
            'replacement_name_ru_snapshot' => fn (array $attributes): string => $this->replacement($attributes)->name_ru,
            'replacement_unit_code_snapshot' => fn (array $attributes) => $this->replacement($attributes)->unit_code,
            'proposed_customer_unit_price_uzs' => 12650,
            'proposed_actual_market_price_uzs' => 11000,
        ]);
    }

    public function reducedQuantity(string $quantity = '1.000'): self
    {
        return $this->state(fn (): array => [
            'type' => ApprovalType::ReducedQuantity,
            'proposed_quantity' => $quantity,
            'proposed_customer_unit_price_uzs' => null,
            'proposed_actual_market_price_uzs' => null,
        ]);
    }

    /**
     * Approved: the proposal is written onto the line, which returns to
     * `pending` (`DL-3` S-7, `DL-54` (5)).
     */
    public function approved(): self
    {
        return $this->decidedByTheCustomer(ApprovalStatus::Approved, ApprovalResolution::Approved)
            ->afterCreating(function (CustomerApproval $approval): void {
                $applied = match ($approval->type) {
                    ApprovalType::PriceOverTolerance => $approval->replacement_product_id === null
                        ? ['approved_unit_price_ceiling_uzs' => $approval->proposed_customer_unit_price_uzs]
                        : ['approved_replacement_price_uzs' => $approval->proposed_customer_unit_price_uzs],
                    ApprovalType::Substitution => [
                        'fulfilled_product_id' => $approval->replacement_product_id,
                        'fulfilled_product_name_uz_snapshot' => $approval->replacement_name_uz_snapshot,
                        'fulfilled_product_name_ru_snapshot' => $approval->replacement_name_ru_snapshot,
                        'fulfilled_unit_code_snapshot' => $approval->replacement_unit_code_snapshot,
                        'substitution_resolution' => SubstitutionResolution::Approved,
                        'approved_replacement_price_uzs' => $approval->proposed_customer_unit_price_uzs,
                    ],
                    ApprovalType::ReducedQuantity => ['approved_quantity_cap' => $approval->proposed_quantity],
                };

                $approval->item->forceFill(['status' => OrderItemStatus::Pending, ...$applied])->save();
            });
    }

    /**
     * Rejected: the line is removed (`BR-APP-006`).
     */
    public function rejected(): self
    {
        return $this->decidedByTheCustomer(ApprovalStatus::Rejected, ApprovalResolution::Rejected)
            ->afterCreating(fn (CustomerApproval $approval) => self::remove($approval->item, ItemRemovedReason::CustomerRejected));
    }

    /**
     * Expired unanswered, its timers behind it, not yet resolved by an
     * Operator; the line still awaits.
     */
    public function expired(): self
    {
        return $this->state(fn (): array => [
            'status' => ApprovalStatus::Expired,
            'attention_at' => now()->subMinutes(20),
            'expires_at' => now(),
        ]);
    }

    /**
     * Expired, and resolved by an Operator removing the line (`BR-APP-007`).
     */
    public function removedByAnOperator(): self
    {
        return $this->expired()->state(fn (): array => [
            'resolution' => ApprovalResolution::RemoveItem,
            'resolved_by_user_id' => User::factory()->role(Role::Operator),
            'resolved_at' => now(),
        ])->afterCreating(fn (CustomerApproval $approval) => self::remove($approval->item, ItemRemovedReason::ApprovalExpired));
    }

    /**
     * Ended with its order, which an approved cancellation request cancelled
     * (`DL-54` (12)): the order is cancelled, its Shopper's assignment ended
     * and its open lines removed.
     */
    public function cancelled(): self
    {
        return $this->state(fn (): array => [
            'status' => ApprovalStatus::Cancelled,
            'resolved_at' => now(),
        ])->afterCreating(function (CustomerApproval $approval): void {
            $order = $approval->order;
            $order->forceFill([
                'status' => OrderStatus::Cancelled,
                'cancelled_at' => now(),
                'cancellation_reason_code' => CancellationReason::CancellationRequestApproved,
            ])->save();
            $order->shopperAssignments()->whereNull('ended_at')->update([
                'ended_at' => now(),
                'ended_reason' => AssignmentEndReason::OrderCancelled->value,
            ]);
            $order->items()
                ->whereIn('status', [OrderItemStatus::Pending->value, OrderItemStatus::AwaitingCustomer->value])
                ->get()
                ->each(fn (OrderItem $item) => self::remove($item, ItemRemovedReason::OrderCancelled));
        });
    }

    private function decidedByTheCustomer(ApprovalStatus $status, ApprovalResolution $resolution): self
    {
        return $this->state(fn (): array => [
            'status' => $status,
            'resolution' => $resolution,
            'resolved_by_user_id' => fn (array $attributes): string => $this->item($attributes)->order->customer_id,
            'resolved_at' => now(),
        ]);
    }

    private static function remove(OrderItem $item, ItemRemovedReason $reason): void
    {
        $item->forceFill([
            'status' => OrderItemStatus::Removed,
            'removed_reason_code' => $reason,
            'removed_at' => now(),
            'billable_quantity' => '0',
            'line_total_uzs' => 0,
        ])->save();
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function item(array $attributes): OrderItem
    {
        return OrderItem::query()->with('order.currentShopperAssignment')->findOrFail($attributes['order_item_id']);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function replacement(array $attributes): Product
    {
        return Product::query()->findOrFail($attributes['replacement_product_id']);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function newModel(array $attributes = []): CustomerApproval
    {
        return (new CustomerApproval)->forceFill($attributes);
    }
}
