<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Enums\ItemRemovedReason;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\PriceMode;
use App\Models\Enums\SubstitutionPolicy;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Builds an order line for a product, snapshotted from that product at a 15 %
 * markup: two units of whatever the product sells, pending. A fixed line comes
 * from a fixed product; [purchased] and [removed] set what those states imply
 * (`order_items_*_check`).
 *
 * @extends Factory<OrderItem>
 */
final class OrderItemFactory extends Factory
{
    protected $model = OrderItem::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'order_id' => Order::factory(),
            'product_id' => Product::factory(),
            'product_name_uz_snapshot' => fn (array $attributes): string => $this->product($attributes)->name_uz,
            'product_name_ru_snapshot' => fn (array $attributes): string => $this->product($attributes)->name_ru,
            'unit_code_snapshot' => fn (array $attributes) => $this->product($attributes)->unit_code,
            'price_mode_snapshot' => fn (array $attributes) => $this->product($attributes)->price_mode,
            'market_price_uzs_snapshot' => fn (array $attributes): int => $this->product($attributes)->market_price_uzs,
            // half_up(market × 1.15) in integer arithmetic, as BR-PRICE-001.
            'customer_unit_price_uzs_snapshot' => fn (array $attributes): int => intdiv(
                $this->product($attributes)->market_price_uzs * 11500 + 5000,
                10000
            ),
            'markup_percent_snapshot' => '15.00',
            'ordered_quantity' => '2.000',
            'purchased_quantity' => null,
            'billable_quantity' => '0.000',
            'customer_note_snapshot' => null,
            'substitution_policy_snapshot' => SubstitutionPolicy::AllowSimilar,
            'status' => OrderItemStatus::Pending,
        ];
    }

    public function awaitingCustomer(): self
    {
        return $this->state(fn (): array => ['status' => OrderItemStatus::AwaitingCustomer]);
    }

    /**
     * Bought as ordered, at the snapshotted customer price.
     */
    public function purchased(): self
    {
        // Each value is a closure, so it is computed when the attributes are
        // expanded, after the product and the snapshots above are resolved; a
        // state closure itself would still see the product as a factory.
        return $this->state(fn (): array => [
            'status' => OrderItemStatus::Purchased,
            'purchased_quantity' => fn (array $attributes): string => (string) $attributes['ordered_quantity'],
            'billable_quantity' => fn (array $attributes): string => (string) $attributes['ordered_quantity'],
            // An estimate line is bought at its estimate's market price; the
            // application requires the actual price for it (docs/08 section 14).
            'actual_market_price_uzs' => fn (array $attributes): ?int => PriceMode::from(
                $attributes['price_mode_snapshot'] instanceof PriceMode
                    ? $attributes['price_mode_snapshot']->value
                    : (string) $attributes['price_mode_snapshot']
            ) === PriceMode::Estimate ? (int) $attributes['market_price_uzs_snapshot'] : null,
            'billable_unit_price_uzs' => fn (array $attributes): int => (int) $attributes['customer_unit_price_uzs_snapshot'],
            'line_total_uzs' => fn (array $attributes): int => intdiv(
                (int) $attributes['customer_unit_price_uzs_snapshot'] * self::thousandths((string) $attributes['ordered_quantity']) + 500,
                1000
            ),
            'fulfilled_product_id' => fn (array $attributes): string => $this->product($attributes)->id,
            'fulfilled_product_name_uz_snapshot' => fn (array $attributes): string => $this->product($attributes)->name_uz,
            'fulfilled_product_name_ru_snapshot' => fn (array $attributes): string => $this->product($attributes)->name_ru,
            'fulfilled_unit_code_snapshot' => fn (array $attributes) => $this->product($attributes)->unit_code,
        ]);
    }

    public function removed(ItemRemovedReason $reason = ItemRemovedReason::CustomerRemoved): self
    {
        return $this->state(fn (): array => [
            'status' => OrderItemStatus::Removed,
            'removed_reason_code' => $reason,
            'removed_at' => now(),
            'billable_quantity' => '0.000',
            'line_total_uzs' => 0,
        ]);
    }

    /** A decimal quantity string as whole thousandths: '2.5' → 2500. */
    private static function thousandths(string $quantity): int
    {
        [$whole, $fraction] = array_pad(explode('.', $quantity, 2), 2, '');

        return (int) $whole * 1000 + (int) str_pad(substr($fraction, 0, 3), 3, '0');
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function product(array $attributes): Product
    {
        return Product::query()->findOrFail($attributes['product_id']);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function newModel(array $attributes = []): OrderItem
    {
        return (new OrderItem)->forceFill($attributes);
    }
}
