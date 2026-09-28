<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\CustomerApproval;
use App\Models\Enums\ApprovalResolution;
use App\Models\Enums\ApprovalStatus;
use App\Models\Enums\ApprovalType;
use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Builds a pending price question on a line awaiting the Customer, in an order
 * being shopped, asked by that order's Shopper ten and thirty minutes before
 * its attention and expiry (`BR-APP-002`, `BR-APP-003`): 20 000 paid at the
 * stall, 23 000 to the Customer under the 15 % markup. The states make the
 * other questions and every resolution.
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
     * A replacement at 11 000 paid, 12 650 to the Customer.
     */
    public function substitution(): self
    {
        return $this->state(fn (): array => [
            'type' => ApprovalType::Substitution,
            'replacement_product_id' => Product::factory(),
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

    public function approved(): self
    {
        return $this->decidedByTheCustomer(ApprovalStatus::Approved, ApprovalResolution::Approved);
    }

    public function rejected(): self
    {
        return $this->decidedByTheCustomer(ApprovalStatus::Rejected, ApprovalResolution::Rejected);
    }

    /**
     * Expired unanswered, its timers behind it, not yet resolved by an Operator.
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
        ]);
    }

    public function cancelled(): self
    {
        return $this->state(fn (): array => [
            'status' => ApprovalStatus::Cancelled,
            'resolved_at' => now(),
        ]);
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
