<?php

declare(strict_types=1);

namespace App\Modules\Orders\Operations;

use App\Models\Enums\ApprovalStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\PaymentMethod;
use App\Models\Order;
use App\Modules\Orders\CustomerOrders;
use App\Modules\Orders\OrderLineSums;
use App\Modules\Settings\WorkingHours;
use App\Support\Search\TextSearch;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Query\Builder as QueryBuilder;

/**
 * The orders on the Operator's and Admin's board (`docs/09` section 38,
 * `DL-37` (16)): every order, newest first, narrowed by status, the Shopper
 * and the Courier a row names (`DL-54` (14)), the payment method, the day it
 * was placed in `Asia/Tashkent`, an attention type, whether it waits on the
 * Customer, and a search over the order number, the Customer's phone digits
 * and name, the name folded as `TextSearch` folds it (`DL-44` (4)). Each
 * order carries its self-order mark (`SelfOrderMark`).
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
        ?string $courierId = null,
        ?PaymentMethod $paymentMethod = null,
        ?CarbonImmutable $from = null,
        ?CarbonImmutable $to = null,
        ?string $attention = null,
        ?string $search = null,
        ?bool $awaitingCustomer = null,
    ): Builder {
        $orders = SelfOrderMark::add(CustomerOrders::withPendingApprovalCount(OrderLineSums::add(Order::query())))
            ->with(['namedShopperAssignment.shopper', 'namedCourierAssignment.courier']);

        if ($status !== null) {
            $orders->where('orders.status', $status->value);
        }
        if ($shopperId !== null) {
            $orders->whereHas('namedShopperAssignment', static fn (Builder $assignment) => $assignment->where('shopper_id', $shopperId));
        }
        if ($courierId !== null) {
            $orders->whereHas('namedCourierAssignment', static fn (Builder $assignment) => $assignment->where('courier_id', $courierId));
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
        if ($attention !== null) {
            Attention::narrow($orders, $attention);
        }
        if ($awaitingCustomer !== null) {
            // DL-3 S-6: orders waiting on the Customer — an approval still
            // open, one past its expiry left out as every read leaves it.
            $open = static fn (QueryBuilder $approval) => $approval->selectRaw('1')
                ->from('customer_approvals')
                ->whereColumn('customer_approvals.order_id', 'orders.id')
                ->where('customer_approvals.status', ApprovalStatus::Pending->value)
                ->where('customer_approvals.expires_at', '>', now());
            $awaitingCustomer ? $orders->whereExists($open) : $orders->whereNotExists($open);
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
        if ($term === '') {
            return;
        }
        $digits = (string) preg_replace('/\D/', '', $term);

        $orders->where(static function (Builder $match) use ($term, $digits): void {
            TextSearch::contains($match, 'orders.recipient_name_snapshot', $term);

            if ($digits !== '' && ctype_digit($term) && strlen($digits) <= 18) {
                $match->orWhere('orders.order_number', (int) $digits);
            }
            if (strlen($digits) >= 3) {
                $match->orWhere('orders.recipient_phone_snapshot', 'like', '%'.$digits.'%');
            }
        });
    }
}
