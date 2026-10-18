<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Exceptions\ApiException;
use App\Models\Order;
use App\Models\OrderRating;
use App\Models\User;
use App\Support\Scope\ScopedLookup;
use Illuminate\Support\Facades\DB;

/**
 * `POST /operations/orders/{order}/rating/review` (`docs/09` section 60,
 * `BR-RATE-003`, `DL-91` (5)): an Operator or Admin marks the rating reviewed
 * after calling the Customer.
 *
 * Under the rating's lock the reviewer and the instant are written once; a
 * review already done is a natural repeat and changes nothing. An order
 * without a rating is `409 order_not_rated`. The order itself is untouched.
 */
final class ReviewOrderRating
{
    public function review(User $staff, string $orderId): Order
    {
        return DB::transaction(function () use ($staff, $orderId): Order {
            $order = ScopedLookup::firstOrNotFound(Order::query()->whereKey($orderId));

            $rating = OrderRating::query()->where('order_id', $order->id)->lockForUpdate()->first();
            if ($rating === null) {
                throw ApiException::conflict('order_not_rated');
            }

            if ($rating->reviewed_at === null) {
                $rating->forceFill(['reviewed_by_user_id' => $staff->id, 'reviewed_at' => now()])->save();
            }

            return $order;
        });
    }
}
