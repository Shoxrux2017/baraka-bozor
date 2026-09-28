<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Exceptions\ApiException;
use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\CancellationRequestStatus;
use App\Models\Order;
use App\Models\OrderCourierAssignment;
use App\Models\User;
use App\Support\Scope\ScopedLookup;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Relations\Relation;
use Illuminate\Database\Query\Builder as QueryBuilder;

/**
 * The orders a Courier reaches (`BR-ASSIGN-004`, `DL-54` (3)): those the
 * Courier holds a current assignment on. Any other order — one whose
 * assignment was replaced or has ended included — stays outside the scope and
 * answers the scope-safe `404` (`ScopedLookup`), as `ShopperOrders` does for
 * the Shopper.
 */
final class CourierOrders
{
    /**
     * @return Builder<Order>
     */
    public static function current(User $courier): Builder
    {
        return Order::query()->whereExists(static fn (QueryBuilder $assignment) => $assignment->selectRaw('1')
            ->from('order_courier_assignments')
            ->whereColumn('order_courier_assignments.order_id', 'orders.id')
            ->where('order_courier_assignments.courier_id', $courier->id)
            ->whereNull('order_courier_assignments.ended_at'));
    }

    /**
     * The order under its lock, with the Courier's own current assignment read
     * after the lock: the scope's `EXISTS` is judged before the lock is
     * granted, so a reassignment it waited on would otherwise go unseen
     * (`DL-56` (6)).
     *
     * @return array{Order, OrderCourierAssignment}
     */
    public static function lockCurrent(User $courier, string $orderId): array
    {
        $order = ScopedLookup::lockOrNotFound(self::current($courier)->whereKey($orderId));
        $assignment = $order->currentCourierAssignment()->where('courier_id', $courier->id)->first();

        if ($assignment === null) {
            throw ApiException::notFound();
        }

        return [$order->setRelation('currentCourierAssignment', $assignment), $assignment];
    }

    /**
     * The order a Courier's delivered or not-delivered ended their assignment
     * on, for a replay of the one and a repeat of the other (`DL-54` (3)):
     * reached only while that assignment is the order's latest Courier
     * assignment and ended as the action ends it; otherwise the scope-safe
     * `404`. The answer shows that assignment as the caller's own.
     */
    public static function endedBy(User $courier, string $orderId, AssignmentEndReason $reason): Order
    {
        /** @var OrderCourierAssignment|null $latest */
        $latest = OrderCourierAssignment::query()
            ->where('order_id', $orderId)
            ->orderByDesc('assigned_at')
            ->orderByDesc('id')
            ->first();

        if ($latest === null || $latest->courier_id !== $courier->id || $latest->ended_reason !== $reason) {
            throw ApiException::notFound();
        }

        return $latest->order->setRelation('currentCourierAssignment', $latest);
    }

    /**
     * What the Courier's order shows beside the order itself
     * (`CourierOrderResource`): the caller's own assignment, whether a
     * cancellation request is pending, and, without a handoff point, the
     * Shopper who bought it.
     *
     * @param  Builder<Order>  $orders
     * @return Builder<Order>
     */
    public static function withDetails(Builder $orders, User $courier): Builder
    {
        return $orders->with(self::relations($courier))->withExists(self::pendingRequest());
    }

    /**
     * The same, for an order an action answers. The assignment the action read
     * under the order lock, or ended, is kept as it was, so the answer shows
     * the caller's own and never a Courier who replaced them since.
     */
    public static function loadDetails(Order $order, User $courier): Order
    {
        return $order->loadMissing(self::relations($courier))->loadExists(self::pendingRequest());
    }

    /**
     * @return array<array-key, mixed>
     */
    private static function relations(User $courier): array
    {
        $relations = [
            'currentCourierAssignment' => static fn (Relation $assignment) => $assignment->where('courier_id', $courier->id),
        ];
        if (! config('delivery.handoff_point')) {
            $relations[] = 'namedShopperAssignment.shopper';
        }

        return $relations;
    }

    /**
     * @return array<string, mixed>
     */
    private static function pendingRequest(): array
    {
        return ['cancellationRequests as cancellation_request_pending' => static fn (Builder $request) => $request
            ->where('status', CancellationRequestStatus::Pending->value)];
    }
}
