<?php

declare(strict_types=1);

namespace App\Modules\Orders\Operations;

use App\Models\Enums\ApprovalStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Order;
use App\Models\OrderShopperAssignment;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Query\Builder as QueryBuilder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;

/**
 * The Operator's attention list (`docs/09` section 38, `DL-37` (16),
 * `DL-54` (13), `DL-60`): what the wave can produce, one item per open order
 * and type, the one waiting longest first.
 *
 * - `self_order` — the order's current Shopper assignment is flagged a
 *   self-order (`BR-ASSIGN-005`, interview 6.4), since its `assigned_at`.
 * - `approval_pending` — a question has waited ten minutes without an answer
 *   and has not expired: the Operator calls the Customer (`BR-APP-002`), since
 *   the earliest such `attention_at`.
 * - `approval_expired` — a question expired and no Operator has removed its
 *   line yet (`BR-APP-007`), a pending one past its expiry included, as every
 *   read shows it (`DL-54` (8)), since the earliest `expires_at`.
 *
 * Each other type arrives with the wave that creates its state. An item names
 * the Shopper concerned, and the Courier from W3-8.
 */
final class Attention
{
    public const SELF_ORDER = 'self_order';

    public const APPROVAL_PENDING = 'approval_pending';

    public const APPROVAL_EXPIRED = 'approval_expired';

    /** @var list<string> */
    public const TYPES = [self::APPROVAL_PENDING, self::APPROVAL_EXPIRED, self::SELF_ORDER];

    /**
     * Narrows orders to those with an item of the type.
     *
     * @param  Builder<Order>  $orders
     * @return Builder<Order>
     */
    public static function narrow(Builder $orders, string $type): Builder
    {
        return match ($type) {
            self::SELF_ORDER => self::selfOrders($orders),
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
     * Narrows orders to those with a current self-order assignment.
     *
     * @param  Builder<Order>  $orders
     * @return Builder<Order>
     */
    public static function selfOrders(Builder $orders): Builder
    {
        return self::open($orders)
            ->whereExists(static fn (QueryBuilder $assignment) => $assignment->selectRaw('1')
                ->from('order_shopper_assignments')
                ->whereColumn('order_shopper_assignments.order_id', 'orders.id')
                ->whereNull('order_shopper_assignments.ended_at')
                ->where('order_shopper_assignments.is_self_order', true));
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
     * @return list<array{type: string, order_id: string, order_number: int, since: string, shopper: array{id: string, full_name: string|null}|null, courier: null}>
     */
    public static function items(): array
    {
        $now = now();
        $items = [...self::selfOrderItems(), ...self::approvalItems(self::APPROVAL_PENDING, $now), ...self::approvalItems(self::APPROVAL_EXPIRED, $now)];

        usort($items, static fn (array $a, array $b): int => [$a['since'], $a['order_number'], $a['type']] <=> [$b['since'], $b['order_number'], $b['type']]);

        return $items;
    }

    /**
     * @return list<array{type: string, order_id: string, order_number: int, since: string, shopper: array{id: string, full_name: string|null}|null, courier: null}>
     */
    private static function selfOrderItems(): array
    {
        $assignments = OrderShopperAssignment::query()
            ->with(['order', 'shopper'])
            ->whereNull('ended_at')
            ->where('is_self_order', true)
            ->whereHas('order', static fn (Builder $order) => $order->whereIn('status', self::openStatuses()))
            ->get();

        return $assignments->map(static fn (OrderShopperAssignment $assignment): array => [
            'type' => self::SELF_ORDER,
            'order_id' => $assignment->order_id,
            'order_number' => $assignment->order->order_number,
            'since' => $assignment->assigned_at->toIso8601ZuluString(),
            'shopper' => self::person($assignment->shopper),
            'courier' => null,
        ])->values()->all();
    }

    /**
     * One item per open order with a question of the kind, since its earliest
     * instant of that kind.
     *
     * @return list<array{type: string, order_id: string, order_number: int, since: string, shopper: array{id: string, full_name: string|null}|null, courier: null}>
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
     * @return array{id: string, full_name: string|null}
     */
    private static function person(User $user): array
    {
        return ['id' => $user->id, 'full_name' => $user->full_name];
    }
}
