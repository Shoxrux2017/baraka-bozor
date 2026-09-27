<?php

declare(strict_types=1);

namespace App\Modules\Orders\Operations;

use App\Models\Enums\OrderStatus;
use App\Models\Enums\PaymentMethod;
use App\Models\Order;
use App\Modules\Orders\OrderLineSums;
use App\Modules\Settings\WorkingHours;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Query\Builder as QueryBuilder;

/**
 * The orders on the Operator's and Admin's board (`docs/09` section 38,
 * `DL-37` (16)): every order, newest first, narrowed by status, the current
 * Shopper, the payment method, the day it was placed in `Asia/Tashkent`, an
 * attention type, and a search over the order number, the Customer's phone
 * digits and name.
 */
final class OrderBoard
{
    /** The states an order is still being worked in. */
    public const OPEN = [
        OrderStatus::New,
        OrderStatus::ShoppingAssigned,
        OrderStatus::Shopping,
        OrderStatus::FinalPaymentPending,
        OrderStatus::ReadyForDelivery,
        OrderStatus::DeliveryAssigned,
        OrderStatus::OnTheWay,
    ];

    /**
     * @return Builder<Order>
     */
    public static function orders(
        ?OrderStatus $status = null,
        ?string $shopperId = null,
        ?PaymentMethod $paymentMethod = null,
        ?CarbonImmutable $from = null,
        ?CarbonImmutable $to = null,
        ?string $attention = null,
        ?string $search = null,
    ): Builder {
        $orders = OrderLineSums::add(Order::query())->with('currentShopperAssignment.shopper');

        if ($status !== null) {
            $orders->where('orders.status', $status->value);
        }
        if ($shopperId !== null) {
            $orders->whereExists(static fn (QueryBuilder $assignment) => $assignment->selectRaw('1')
                ->from('order_shopper_assignments')
                ->whereColumn('order_shopper_assignments.order_id', 'orders.id')
                ->whereNull('order_shopper_assignments.ended_at')
                ->where('order_shopper_assignments.shopper_id', $shopperId));
        }
        if ($paymentMethod !== null) {
            $orders->where('orders.payment_method', $paymentMethod->value);
        }
        if ($from !== null) {
            $orders->where('orders.created_at', '>=', $from->setTimezone(WorkingHours::ZONE)->startOfDay()->utc());
        }
        if ($to !== null) {
            $orders->where('orders.created_at', '<', $to->setTimezone(WorkingHours::ZONE)->startOfDay()->addDay()->utc());
        }
        if ($attention === Attention::SELF_ORDER) {
            Attention::selfOrders($orders);
        }
        if ($search !== null) {
            self::search($orders, $search);
        }

        return $orders->orderByDesc('orders.created_at')->orderByDesc('orders.order_number');
    }

    /**
     * @param  Builder<Order>  $orders
     */
    private static function search(Builder $orders, string $term): void
    {
        $term = trim($term);
        $digits = (string) preg_replace('/\D/', '', $term);
        $name = '%'.addcslashes(mb_strtolower($term), '\\%_').'%';

        $orders->where(static function (Builder $match) use ($term, $digits, $name): void {
            $match->whereRaw('lower(orders.recipient_name_snapshot) like ?', [$name]);

            if ($digits !== '' && ctype_digit($term) && strlen($digits) <= 18) {
                $match->orWhere('orders.order_number', (int) $digits);
            }
            if (strlen($digits) >= 3) {
                $match->orWhere('orders.recipient_phone_snapshot', 'like', '%'.$digits.'%');
            }
        });
    }
}
