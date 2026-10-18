<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\Enums\OrderStatus;
use App\Models\Order;
use Carbon\CarbonInterface;

/**
 * When a Customer may rate (`BR-RATE-001`, `DL-91` (4)): a `completed` order
 * with no rating yet, up to and including seven days after its completion.
 * A rating of up to three stars is a low one (`BR-RATE-002`, `BR-RATE-003`).
 */
final class OrderRatings
{
    public const WINDOW_DAYS = 7;

    public const LOW_MAX_STARS = 3;

    /**
     * Expects `rating` loaded.
     */
    public static function canRate(Order $order, CarbonInterface $now): bool
    {
        return $order->status === OrderStatus::Completed
            && $order->rating === null
            && self::windowOpen($order, $now);
    }

    public static function windowOpen(Order $order, CarbonInterface $now): bool
    {
        return $order->completed_at !== null
            && $now->lessThanOrEqualTo($order->completed_at->copy()->addDays(self::WINDOW_DAYS));
    }
}
