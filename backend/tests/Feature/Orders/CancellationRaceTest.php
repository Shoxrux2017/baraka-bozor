<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderShopperAssignment;
use Illuminate\Database\Connection;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Tests\Support\Concurrency\RunsInAnotherProcess;
use Tests\TestCase;

/**
 * The Shopper's purchase and unavailable line racing the Operator's approval
 * of the Customer's cancellation request (W3-11, `DL-54` (12), `DL-57`
 * review, `DL-65`): the Shopper's action waited on the order lock the
 * approval held, and must then find the order no longer the Shopper's — the
 * scope-safe `404` — rather than buy, or mark unavailable, a line the
 * cancellation removed.
 *
 * A second connection plays the approval — it holds the order, ends the
 * Shopper's assignment, removes the open lines, cancels the order and
 * commits, without the history row this test could not remove — and the
 * Shopper's action runs in another process. No test transaction wraps this
 * class: it removes what it committed.
 */
final class CancellationRaceTest extends TestCase
{
    use RunsInAnotherProcess;

    private const SECOND = 'pgsql_second';

    private ?Order $order = null;

    private ?OrderItem $line = null;

    protected function setUp(): void
    {
        parent::setUp();

        if (! Schema::hasTable('orders')) {
            $this->artisan('migrate');
        }

        config(['database.connections.'.self::SECOND => config('database.connections.pgsql')]);

        $this->order = Order::factory()->shopping()->create();
        $this->line = OrderItem::factory()->for($this->order)->create();
    }

    protected function tearDown(): void
    {
        if (config()->has('database.connections.'.self::SECOND)) {
            $second = DB::connection(self::SECOND);
            while ($second->transactionLevel() > 0) {
                $second->rollBack();
            }
            DB::purge(self::SECOND);
        }

        if ($this->order !== null) {
            $this->removeEverything($this->order);
        }

        parent::tearDown();
    }

    public function test_a_purchase_that_waited_on_the_cancellation_is_not_found(): void
    {
        [$order, $line, $shopper] = $this->fixture();

        $second = $this->holdOrder($order);
        $process = $this->startElsewhere('shopper.purchase', $shopper, $order->id, $line->id, '2.000', '16000', (string) Str::uuid());
        $this->waitUntilAnotherBackendWaitsOnALock();
        $this->cancelOn($second, $order);
        $second->commit();

        $outcome = $this->outcomeOf($process);
        $this->assertFalse($outcome['ok'], 'A line of a cancelled order was bought.');
        $this->assertSame('resource_not_found', $outcome['code']);
        $this->assertSame(['removed', 'order_cancelled', null], $this->lineState($line));
        $this->assertSame(0, DB::table('order_history')->where('order_id', $order->id)->count());
    }

    public function test_an_unavailable_line_that_waited_on_the_cancellation_is_not_found(): void
    {
        [$order, $line, $shopper] = $this->fixture();

        $second = $this->holdOrder($order);
        $process = $this->startElsewhere('shopper.unavailable', $shopper, $order->id, $line->id);
        $this->waitUntilAnotherBackendWaitsOnALock();
        $this->cancelOn($second, $order);
        $second->commit();

        $outcome = $this->outcomeOf($process);
        $this->assertFalse($outcome['ok'], 'A line of a cancelled order was marked unavailable.');
        $this->assertSame('resource_not_found', $outcome['code']);
        $this->assertSame(['removed', 'order_cancelled', null], $this->lineState($line));
        $this->assertSame(0, DB::table('order_history')->where('order_id', $order->id)->count());
    }

    /**
     * @return array{Order, OrderItem, string}
     */
    private function fixture(): array
    {
        $order = $this->order ?? $this->fail('No order.');
        $line = $this->line ?? $this->fail('No line.');

        return [$order, $line, OrderShopperAssignment::query()->where('order_id', $order->id)->sole()->shopper_id];
    }

    private function holdOrder(Order $order): Connection
    {
        $second = DB::connection(self::SECOND);
        $second->beginTransaction();
        $second->table('orders')->where('id', $order->id)->lockForUpdate()->first();

        return $second;
    }

    /**
     * What the approval of the Customer's request writes to the order, without
     * its history row and its request.
     */
    private function cancelOn(Connection $second, Order $order): void
    {
        $second->table('order_items')->where('order_id', $order->id)->whereIn('status', ['pending', 'awaiting_customer'])->update([
            'status' => 'removed',
            'removed_reason_code' => 'order_cancelled',
            'removed_at' => now(),
            'billable_quantity' => '0',
            'line_total_uzs' => 0,
        ]);
        $second->table('order_shopper_assignments')->where('order_id', $order->id)->whereNull('ended_at')
            ->update(['ended_at' => now(), 'ended_reason' => 'order_cancelled']);
        $second->table('orders')->where('id', $order->id)->update([
            'status' => 'cancelled',
            'cancelled_at' => now(),
            'cancellation_reason_code' => 'cancellation_request_approved',
        ]);
    }

    /**
     * @return array{string, string|null, int|null}
     */
    private function lineState(OrderItem $line): array
    {
        $row = DB::table('order_items')->where('id', $line->id)->first(['status', 'removed_reason_code', 'billable_unit_price_uzs']);

        return [(string) $row?->status, $row?->removed_reason_code, $row?->billable_unit_price_uzs];
    }

    private function removeEverything(Order $order): void
    {
        $order = Order::query()->with(['shopperAssignments', 'items.product.category'])->find($order->id);
        if ($order === null) {
            return;
        }

        $users = array_filter([
            $order->customer_id,
            ...$order->shopperAssignments->pluck('shopper_id')->all(),
            ...$order->shopperAssignments->pluck('assigned_by_user_id')->all(),
            ...$order->items->map(static fn (OrderItem $item) => $item->product->created_by_user_id)->all(),
            ...$order->items->map(static fn (OrderItem $item) => $item->product->category->created_by_user_id)->all(),
        ]);

        try {
            DB::transaction(static function () use ($order): void {
                DB::table('idempotency_keys')->whereIn('actor_user_id', $order->shopperAssignments->pluck('shopper_id')->all())->delete();
                DB::table('order_items')->where('order_id', $order->id)->delete();
                DB::table('order_shopper_assignments')->where('order_id', $order->id)->delete();
                DB::table('orders')->where('id', $order->id)->delete();
                DB::table('carts')->where('id', $order->source_cart_id)->delete();
                DB::table('customer_addresses')->where('id', $order->source_address_id)->delete();
                foreach ($order->items as $item) {
                    DB::table('products')->where('id', $item->product_id)->delete();
                    DB::table('categories')->where('id', $item->product->category_id)->delete();
                }
            });
            foreach (array_unique($users) as $user) {
                DB::table('users')->where('id', $user)->delete();
            }
        } catch (QueryException) {
            // Left behind only when the test already failed on what it checks.
        }
    }
}
