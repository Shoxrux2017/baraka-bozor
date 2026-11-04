<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\PriceMode;
use App\Models\Order;
use App\Models\OrderItem;
use App\Modules\Settings\ServiceFeeCalculator;
use App\Support\Money\MoneyCalculator;
use App\Support\Money\Quantity;

/**
 * An order's totals as `DL-37` (10) defines them. Until shopping completes
 * they are computed from the order's snapshots over the lines not removed —
 * the merchandise as the sum of each line's price in force times its quantity
 * in force (`DL-130` (1)), the service fee by the snapshotted rule, the delivery fee
 * snapshot — and labelled like the preview: `estimate` when any line is an
 * estimate, `final` when every line has a guaranteed price. From completion
 * they are the stored final amounts. A cancelled order owes nothing: every
 * amount is `null` and the kind is `none`.
 */
final readonly class OrderTotals
{
    private function __construct(
        public ?int $merchandiseSubtotalUzs,
        public ?int $serviceFeeUzs,
        public ?int $deliveryFeeUzs,
        public ?int $totalUzs,
        public string $kind,
    ) {}

    /**
     * @param  iterable<OrderItem>  $items
     */
    public static function of(Order $order, iterable $items): self
    {
        if ($order->status === OrderStatus::Cancelled) {
            return new self(null, null, null, null, 'none');
        }

        if ($order->final_total_uzs !== null) {
            return new self(
                $order->final_merchandise_subtotal_uzs,
                $order->final_service_fee_uzs,
                $order->delivery_fee_uzs_snapshot,
                $order->final_total_uzs,
                'final',
            );
        }

        $subtotal = 0;
        $estimate = false;
        foreach ($items as $item) {
            if ($item->status === OrderItemStatus::Removed) {
                continue;
            }
            $subtotal = MoneyCalculator::sum($subtotal, self::lineEstimate($item));
            $estimate = $estimate || $item->price_mode_snapshot === PriceMode::Estimate;
        }

        return self::fromLines($order, $subtotal, $estimate);
    }

    /**
     * The same totals from the lines' sum and whether any is an estimate, as a
     * list query computes them in SQL (`OrderLineSums`), so a
     * page of orders does not load every line.
     */
    public static function fromLines(Order $order, int $subtotal, bool $estimate): self
    {
        if ($order->status === OrderStatus::Cancelled) {
            return new self(null, null, null, null, 'none');
        }

        if ($order->final_total_uzs !== null) {
            return new self(
                $order->final_merchandise_subtotal_uzs,
                $order->final_service_fee_uzs,
                $order->delivery_fee_uzs_snapshot,
                $order->final_total_uzs,
                'final',
            );
        }

        $fee = self::serviceFeeOn($order, $subtotal);

        return new self(
            $subtotal,
            $fee,
            $order->delivery_fee_uzs_snapshot,
            MoneyCalculator::sum($subtotal, $fee, $order->delivery_fee_uzs_snapshot),
            $estimate ? 'estimate' : 'final',
        );
    }

    /**
     * The service fee on a merchandise subtotal by the order's snapshotted
     * rule (`BR-MONEY-005`), for the estimate here and the final amounts
     * (`FinalAmounts`).
     */
    public static function serviceFeeOn(Order $order, int $subtotal): int
    {
        return (new ServiceFeeCalculator(
            $order->service_fee_mode_snapshot,
            $order->service_fee_fixed_uzs_snapshot,
            $order->service_fee_percent_snapshot,
        ))->feeOn($subtotal);
    }

    /**
     * A line's amount as the Customer sees it: the stored total once it is
     * bought or removed, otherwise the price in force times the quantity in
     * force (`DL-130` (1)).
     */
    public static function lineEstimate(OrderItem $item): int
    {
        return $item->line_total_uzs
            ?? MoneyCalculator::lineTotal(self::unitPriceInForce($item), Quantity::fromString(self::quantityInForce($item)));
    }

    /**
     * The unit price the Customer's yes put in force (`DL-130` (1)): the
     * approved replacement price while a replacement is on the line, the
     * approved ceiling while none is, else the snapshotted price. SQL twin:
     * `OrderLineSums`.
     */
    public static function unitPriceInForce(OrderItem $item): int
    {
        return self::agreedUnitPrice($item) ?? $item->customer_unit_price_uzs_snapshot;
    }

    /**
     * The quantity the Customer's yes put in force: the approved cap, else the
     * quantity ordered.
     */
    public static function quantityInForce(OrderItem $item): string
    {
        return $item->approved_quantity_cap ?? $item->ordered_quantity;
    }

    /**
     * The approved price `unitPriceInForce` takes, or `null` when it falls
     * back to the snapshot (`DL-130` (2)).
     */
    public static function agreedUnitPrice(OrderItem $item): ?int
    {
        return $item->fulfilled_product_id !== null
            ? $item->approved_replacement_price_uzs
            : $item->approved_unit_price_ceiling_uzs;
    }
}
