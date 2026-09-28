<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\Enums\PriceMode;
use App\Models\Order;
use App\Models\OrderItem;
use App\Support\Money\MoneyCalculator;
use App\Support\Money\Percentage;

/**
 * The bound of the product bought (`DL-54` (5)): the customer price a
 * purchase, a price question and a price correction are held to.
 *
 * - The original: an estimate's approved ceiling, or else its estimate plus
 *   the order's tolerance (`BR-PRICE-003`). A fixed original bought as itself
 *   has none, since it is billed at its snapshot (`BR-PRICE-002`).
 * - A replacement: the price the Customer approved for it, or else the
 *   automatic ceiling of `BR-PRICE-005` — a fixed original's snapshot, or an
 *   estimate's bound as above. A price approved for another replacement never
 *   counts: a new substitution clears it (`DL-54` (5)).
 *
 * Every bound is also given as the highest market price whose customer price,
 * under the line's own markup (`DL-37` (8)), stays within it (`DL-54` (6)).
 */
final class PriceBound
{
    /**
     * The original's bound, or null for a fixed line, which has none.
     */
    public static function original(OrderItem $item, Order $order): ?int
    {
        if ($item->price_mode_snapshot === PriceMode::Fixed) {
            return null;
        }

        return $item->approved_unit_price_ceiling_uzs ?? self::estimateCeiling($item, $order);
    }

    /**
     * The ceiling a replacement meets without the Customer (`BR-PRICE-005`).
     */
    public static function automatic(OrderItem $item, Order $order): int
    {
        return self::original($item, $order) ?? $item->customer_unit_price_uzs_snapshot;
    }

    /**
     * The authorized replacement's bound.
     */
    public static function replacement(OrderItem $item, Order $order): int
    {
        return $item->approved_replacement_price_uzs ?? self::automatic($item, $order);
    }

    /**
     * The highest market price whose customer price stays within the bound.
     */
    public static function asMarketPrice(int $boundUzs, OrderItem $item): int
    {
        return MoneyCalculator::largestBaseWithin($boundUzs, Percentage::fromString($item->markup_percent_snapshot));
    }

    private static function estimateCeiling(OrderItem $item, Order $order): int
    {
        return MoneyCalculator::increaseByPercent(
            $item->customer_unit_price_uzs_snapshot,
            Percentage::fromString($order->price_tolerance_percent_snapshot),
        );
    }
}
