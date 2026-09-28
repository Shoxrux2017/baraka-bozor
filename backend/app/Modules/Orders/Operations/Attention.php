<?php

declare(strict_types=1);

namespace App\Modules\Orders\Operations;

use App\Models\Enums\ApprovalStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\UserStatus;
use App\Models\Order;
use App\Models\OrderCourierAssignment;
use App\Models\OrderShopperAssignment;
use App\Models\User;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Collection;
use Illuminate\Database\Eloquent\Relations\Relation;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * The Operator's attention list (`docs/09` section 38, `DL-37` (16),
 * `DL-54` (13), `DL-60`): what the wave can produce, one item per open order
 * and type, the one waiting longest first.
 *
 * - `self_order` — the order carries the self-order mark (`SelfOrderMark`,
 *   `BR-ASSIGN-005`, interview 6.4, `DL-54` (14)), since the earliest
 *   assignment that marks it; the item names the Shopper and the Courier
 *   whose assignments mark it, the latest of each.
 * - `staff_blocked` — the order's current Shopper or Courier has been blocked,
 *   and the Operator reassigns it where the rules allow (`DL-54` (13)); since
 *   the earliest such block, naming the one blocked.
 * - `courier_delayed` — an order on the way past its assignment's `delay_at`,
 *   the start plus the threshold snapshotted on the order (`BR-DEL-002`,
 *   `DL-63`); since `delay_at`, naming the Courier.
 * - `approval_pending` — a question has waited ten minutes without an answer
 *   and has not expired: the Operator calls the Customer (`BR-APP-002`), since
 *   the earliest such `attention_at`.
 * - `approval_expired` — a question expired and no Operator has removed its
 *   line yet (`BR-APP-007`), a pending one past its expiry included, as every
 *   read shows it (`DL-54` (8)), since the earliest `expires_at`.
 *
 * Each other type arrives with the task that creates its state. An item names
 * the Shopper and the Courier concerned, each `null` when none is.
 *
 * @phpstan-type Item array{type: string, order_id: string, order_number: int, since: string, shopper: array{id: string, full_name: string|null}|null, courier: array{id: string, full_name: string|null}|null}
 */
final class Attention
{
    public const SELF_ORDER = 'self_order';

    public const APPROVAL_PENDING = 'approval_pending';

    public const APPROVAL_EXPIRED = 'approval_expired';

    public const STAFF_BLOCKED = 'staff_blocked';

    public const COURIER_DELAYED = 'courier_delayed';

    /** @var list<string> */
    public const TYPES = [self::APPROVAL_PENDING, self::APPROVAL_EXPIRED, self::COURIER_DELAYED, self::SELF_ORDER, self::STAFF_BLOCKED];

    /**
     * Narrows orders to those with an item of the type.
     *
     * @param  Builder<Order>  $orders
     * @return Builder<Order>
     */
    public static function narrow(Builder $orders, string $type): Builder
    {
        return match ($type) {
            self::SELF_ORDER => SelfOrderMark::narrow(self::open($orders)),
            self::STAFF_BLOCKED => self::open($orders)->where(static fn (Builder $blocked) => $blocked
                ->whereHas('currentShopperAssignment.shopper', static fn (Builder $staff) => $staff->where('status', UserStatus::Blocked->value))
                ->orWhereHas('currentCourierAssignment.courier', static fn (Builder $staff) => $staff->where('status', UserStatus::Blocked->value))),
            self::COURIER_DELAYED => self::open($orders)
                ->where('orders.status', OrderStatus::OnTheWay->value)
                ->whereHas('currentCourierAssignment', static fn (Builder $assignment) => $assignment->where('delay_at', '<=', now())),
            self::APPROVAL_PENDING => self::open($orders)->whereExists(static fn (QueryBuilder $approval) => self::waitingTooLong(
                $approval->selectRaw('1')->from('customer_approvals')->whereColumn('customer_approvals.order_id', 'orders.id'),
                now(),
            )),
            self::APPROVAL_EXPIRED => self::open($orders)->whereExists(static fn (QueryBuilder $approval) => self::expiredUnresolved(
                $approval->selectRaw('1')->from('customer_approvals')->whereColumn('customer_approvals.order_id', 'orders.id'),
                now(),
            )),
            default => $orders->whereRaw('false'),
        };
    }

    /**
     * How many items the list holds: one per open order and type.
     */
    public static function count(): int
    {
        $count = 0;
        foreach (self::TYPES as $type) {
            $count += self::narrow(Order::query(), $type)->count();
        }

        return $count;
    }

    /**
     * The items, the one waiting longest on top.
     *
     * @return list<Item>
     */
    public static function items(): array
    {
        $now = now();
        $items = [
            ...self::selfOrderItems(),
            ...self::staffBlockedItems(),
            ...self::courierDelayedItems(),
            ...self::approvalItems(self::APPROVAL_PENDING, $now),
            ...self::approvalItems(self::APPROVAL_EXPIRED, $now),
        ];

        usort($items, static fn (array $a, array $b): int => [$a['since'], $a['order_number'], $a['type']] <=> [$b['since'], $b['order_number'], $b['type']]);

        return $items;
    }

    /**
     * @return list<Item>
     */
    private static function selfOrderItems(): array
    {
        $orders = self::narrow(Order::query(), self::SELF_ORDER)
            ->with([
                'shopperAssignments' => static fn (Relation $assignments) => SelfOrderMark::shoppers($assignments->getQuery())->with('shopper'),
                'courierAssignments' => static fn (Relation $assignments) => SelfOrderMark::couriers($assignments->getQuery())->with('courier'),
            ])
            ->get();

        return $orders->map(static function (Order $order): ?array {
            $since = collect([
                ...$order->shopperAssignments->map(static fn (OrderShopperAssignment $assignment): CarbonInterface => $assignment->assigned_at),
                ...$order->courierAssignments->map(static fn (OrderCourierAssignment $assignment): CarbonInterface => $assignment->assigned_at),
            ])->sort()->first();
            // The assignments are read in a statement of their own: one
            // replaced in between may leave nothing marking the order now.
            if ($since === null) {
                return null;
            }
            $shopper = self::latest($order->shopperAssignments);
            $courier = self::latest($order->courierAssignments);

            return [
                'type' => self::SELF_ORDER,
                'order_id' => $order->id,
                'order_number' => $order->order_number,
                'since' => $since->toIso8601ZuluString(),
                'shopper' => $shopper === null ? null : self::person($shopper->shopper),
                'courier' => $courier === null ? null : self::person($courier->courier),
            ];
        })->filter()->values()->all();
    }

    /**
     * @return list<Item>
     */
    private static function staffBlockedItems(): array
    {
        $orders = self::narrow(Order::query(), self::STAFF_BLOCKED)
            ->with(['currentShopperAssignment.shopper', 'currentCourierAssignment.courier'])
            ->get();

        return $orders->map(static function (Order $order): ?array {
            $shopper = self::blocked($order->currentShopperAssignment?->shopper);
            $courier = self::blocked($order->currentCourierAssignment?->courier);
            // A block always has its instant (`users_blocked_at_check`). The
            // people are read in a statement of their own: one unblocked or
            // replaced in between leaves no one blocked on the order now.
            $since = collect([$shopper?->blocked_at, $courier?->blocked_at])->filter()->sort()->first();
            if ($since === null) {
                return null;
            }

            return [
                'type' => self::STAFF_BLOCKED,
                'order_id' => $order->id,
                'order_number' => $order->order_number,
                'since' => $since->toIso8601ZuluString(),
                'shopper' => $shopper === null ? null : self::person($shopper),
                'courier' => $courier === null ? null : self::person($courier),
            ];
        })->filter()->values()->all();
    }

    /**
     * @return list<Item>
     */
    private static function courierDelayedItems(): array
    {
        $orders = self::narrow(Order::query(), self::COURIER_DELAYED)
            ->with('currentCourierAssignment.courier')
            ->get();

        return $orders->map(static function (Order $order): ?array {
            $assignment = $order->currentCourierAssignment;
            // Read in a statement of its own: a delivery that ended in between
            // needs nothing any more.
            if ($assignment?->delay_at === null) {
                return null;
            }

            return [
                'type' => self::COURIER_DELAYED,
                'order_id' => $order->id,
                'order_number' => $order->order_number,
                'since' => $assignment->delay_at->toIso8601ZuluString(),
                'shopper' => null,
                'courier' => self::person($assignment->courier),
            ];
        })->filter()->values()->all();
    }

    /**
     * One item per open order with a question of the kind, since its earliest
     * instant of that kind.
     *
     * @return list<Item>
     */
    private static function approvalItems(string $type, Carbon $now): array
    {
        $approvals = DB::table('customer_approvals');
        $since = $type === self::APPROVAL_PENDING ? 'attention_at' : 'expires_at';
        $type === self::APPROVAL_PENDING ? self::waitingTooLong($approvals, $now) : self::expiredUnresolved($approvals, $now);

        $earliest = $approvals
            ->join('orders', 'orders.id', '=', 'customer_approvals.order_id')
            ->whereIn('orders.status', self::openStatuses())
            ->groupBy('customer_approvals.order_id')
            ->selectRaw("customer_approvals.order_id as order_id, min(customer_approvals.{$since}) as since")
            ->pluck('since', 'order_id');

        if ($earliest->isEmpty()) {
            return [];
        }

        $orders = Order::query()->with('currentShopperAssignment.shopper')->whereKey($earliest->keys()->all())->get();

        return $orders->map(static fn (Order $order): array => [
            'type' => $type,
            'order_id' => $order->id,
            'order_number' => $order->order_number,
            'since' => Carbon::parse((string) $earliest[$order->id])->utc()->toIso8601ZuluString(),
            'shopper' => $order->currentShopperAssignment === null ? null : self::person($order->currentShopperAssignment->shopper),
            'courier' => null,
        ])->values()->all();
    }

    /**
     * Pending, past its ten minutes, not past its thirty.
     */
    private static function waitingTooLong(QueryBuilder $approvals, Carbon $now): QueryBuilder
    {
        return $approvals
            ->where('customer_approvals.status', ApprovalStatus::Pending->value)
            ->where('customer_approvals.attention_at', '<=', $now)
            ->where('customer_approvals.expires_at', '>', $now);
    }

    /**
     * Expired and not yet resolved by an Operator, a pending one past its
     * expiry included.
     */
    private static function expiredUnresolved(QueryBuilder $approvals, Carbon $now): QueryBuilder
    {
        return $approvals->where(static fn (QueryBuilder $expired) => $expired
            ->where(static fn (QueryBuilder $stored) => $stored
                ->where('customer_approvals.status', ApprovalStatus::Expired->value)
                ->whereNull('customer_approvals.resolution'))
            ->orWhere(static fn (QueryBuilder $overdue) => $overdue
                ->where('customer_approvals.status', ApprovalStatus::Pending->value)
                ->where('customer_approvals.expires_at', '<=', $now)));
    }

    /**
     * @param  Builder<Order>  $orders
     * @return Builder<Order>
     */
    private static function open(Builder $orders): Builder
    {
        return $orders->whereIn('orders.status', self::openStatuses());
    }

    /**
     * @return list<string>
     */
    private static function openStatuses(): array
    {
        return array_map(static fn (OrderStatus $status): string => $status->value, OrderBoard::OPEN);
    }

    /**
     * The latest of an order's assignments of one kind.
     *
     * @template TAssignment of OrderShopperAssignment|OrderCourierAssignment
     *
     * @param  Collection<int, TAssignment>  $assignments
     * @return TAssignment|null
     */
    private static function latest(Collection $assignments): OrderShopperAssignment|OrderCourierAssignment|null
    {
        return $assignments->sortBy([['assigned_at', 'desc'], ['id', 'desc']])->first();
    }

    private static function blocked(?User $staff): ?User
    {
        return $staff?->status === UserStatus::Blocked ? $staff : null;
    }

    /**
     * @return array{id: string, full_name: string|null}
     */
    private static function person(User $user): array
    {
        return ['id' => $user->id, 'full_name' => $user->full_name];
    }
}
