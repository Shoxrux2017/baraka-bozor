<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\Enums\OrderStatus;
use App\Models\Order;

/**
 * The Courier as the Customer may see them (`DL-91` (2)): the first word of
 * the name and the phone, only while the order is `on_the_way`, the status
 * the Courier's start sets and delivery or failure ends. In every other
 * status, and with no current Courier, nothing is shown.
 *
 * Expects `currentCourierAssignment.courier` loaded.
 */
final class CourierContact
{
    /**
     * @return array{first_name: string|null, phone: string}|null
     */
    public static function of(Order $order): ?array
    {
        if ($order->status !== OrderStatus::OnTheWay) {
            return null;
        }

        $courier = $order->currentCourierAssignment?->courier;

        if ($courier === null) {
            return null;
        }

        $words = preg_split('/\s+/u', trim((string) $courier->full_name), -1, PREG_SPLIT_NO_EMPTY);

        return [
            'first_name' => $words === false || $words === [] ? null : $words[0],
            'phone' => $courier->phone,
        ];
    }
}
