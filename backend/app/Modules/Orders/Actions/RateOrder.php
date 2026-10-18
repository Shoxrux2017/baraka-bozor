<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Exceptions\ApiException;
use App\Models\Enums\OrderStatus;
use App\Models\Order;
use App\Models\OrderRating;
use App\Models\User;
use App\Modules\Orders\CustomerOrders;
use App\Modules\Orders\OrderRatings;
use App\Support\Scope\ScopedLookup;
use Illuminate\Support\Facades\DB;

/**
 * `POST /customer/orders/{order}/rating` (`docs/09` section 59,
 * `BR-RATE-001`, `BR-RATE-002`, `DL-91` (4)).
 *
 * Under the order's row lock, in this order: an order not `completed` is
 * `409 order_not_rateable`; a rated one answers `created: false` when the
 * body is the same (stars, reasons as a set, trimmed comment) and is
 * `409 order_already_rated` otherwise; past the window of seven days it is
 * `409 rating_window_closed`; then the rating is stored. The order itself is
 * never changed.
 */
final class RateOrder
{
    /**
     * @param  list<string>  $reasons
     * @return array{order: Order, created: bool}
     */
    public function rate(User $customer, string $orderId, int $stars, array $reasons, ?string $comment): array
    {
        return DB::transaction(function () use ($customer, $orderId, $stars, $reasons, $comment): array {
            /** @var Order $order */
            $order = ScopedLookup::lockOrNotFound(CustomerOrders::own($customer)->whereKey($orderId));
            $rating = $order->rating()->first();

            if ($order->status !== OrderStatus::Completed) {
                throw ApiException::conflict('order_not_rateable');
            }

            if ($rating !== null) {
                if ($this->same($rating, $stars, $reasons, $comment)) {
                    return ['order' => $order, 'created' => false];
                }

                throw ApiException::conflict('order_already_rated');
            }

            if (! OrderRatings::windowOpen($order, now())) {
                throw ApiException::conflict('rating_window_closed');
            }

            $new = new OrderRating;
            $new->forceFill([
                'order_id' => $order->id,
                'customer_id' => $customer->id,
                'stars' => $stars,
                'reasons' => $reasons,
                'comment' => $comment,
            ])->save();

            return ['order' => $order, 'created' => true];
        });
    }

    /**
     * @param  list<string>  $reasons
     */
    private function same(OrderRating $rating, int $stars, array $reasons, ?string $comment): bool
    {
        $stored = $rating->reasons;
        sort($stored);
        sort($reasons);

        return $rating->stars === $stars && $stored === $reasons && $rating->comment === $comment;
    }
}
