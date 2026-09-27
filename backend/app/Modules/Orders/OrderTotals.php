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
 * the merchandise as the sum of each line's snapshotted price times its
 * ordered quantity, the service fee by the snapshotted rule, the delivery fee
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

        $fee = (new ServiceFeeCalculator(
            $order->service_fee_mode_snapshot,
            $order->service_fee_fixed_uzs_snapshot,
            $order->service_fee_percent_snapshot,
        ))->feeOn($subtotal);

        return new self(
            $subtotal,
            $fee,
            $order->delivery_fee_uzs_snapshot,
            MoneyCalculator::sum($subtotal, $fee, $order->delivery_fee_uzs_snapshot),
            $estimate ? 'estimate' : 'final',
        );
    }

    /**
     * A line's amount as the Customer sees it: the stored total once it is
     * bought or removed, otherwise its snapshotted price times the quantity
     * ordered.
     */
    public static function lineEstimate(OrderItem $item): int
    {
        return $item->line_total_uzs
            ?? MoneyCalculator::lineTotal($item->customer_unit_price_uzs_snapshot, Quantity::fromString($item->ordered_quantity));
    }
}
