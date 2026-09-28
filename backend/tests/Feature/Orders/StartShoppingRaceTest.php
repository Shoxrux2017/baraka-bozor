<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\Enums\OrderStatus;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderShopperAssignment;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\Support\Concurrency\RunsInAnotherProcess;
use Tests\TestCase;

/**
 * The Customer's edit racing the Shopper's start (W3-2, `BR-ORDER-004`): an
 * edit that waited on the start's order lock reads the start and is refused,
 * so no line changes after shopping began.
 *
 * A second connection plays the Shopper's start — it holds the order, starts
 * shopping and commits, without the history row this test could not remove —
 * and the edit runs in another process. No test transaction wraps this class:
 * it removes what it committed.
 */
final class StartShoppingRaceTest extends TestCase
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

        $this->order = Order::factory()->state(['status' => OrderStatus::ShoppingAssigned])->create();
        OrderShopperAssignment::factory()->accepted()->create(['order_id' => $this->order->id]);
        $this->line = OrderItem::factory()->for($this->order)->create(['ordered_quantity' => '2.000']);
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

        if ($this->order !== null && $this->line !== null) {
            $order = $this->order;
            $product = $this->line->product;
            $assignment = OrderShopperAssignment::query()->where('order_id', $order->id)->first();
            $users = array_filter([
                $order->customer_id,
                $assignment?->shopper_id,
                $assignment?->assigned_by_user_id,
                $product->created_by_user_id,
                $product->category->created_by_user_id,
            ]);
            $this->quietly(static fn () => DB::table('order_items')->where('order_id', $order->id)->delete());
            $this->quietly(static fn () => DB::table('order_shopper_assignments')->where('order_id', $order->id)->delete());
            $this->quietly(static fn () => DB::table('orders')->where('id', $order->id)->delete());
            $this->quietly(static fn () => DB::table('carts')->where('id', $order->source_cart_id)->delete());
            $this->quietly(static fn () => DB::table('customer_addresses')->where('id', $order->source_address_id)->delete());
            $this->quietly(static fn () => DB::table('products')->where('id', $product->id)->delete());
            $this->quietly(static fn () => DB::table('categories')->where('id', $product->category_id)->delete());
            foreach ($users as $user) {
                $this->quietly(static fn () => DB::table('users')->where('id', $user)->delete());
            }
        }

        parent::tearDown();
    }

    public function test_an_edit_that_waited_on_the_start_is_refused(): void
    {
        $order = $this->order ?? $this->fail('No order.');
        $line = $this->line ?? $this->fail('No line.');

        $second = DB::connection(self::SECOND);
        $second->beginTransaction();
        $second->table('orders')->where('id', $order->id)->lockForUpdate()->first();

        $process = $this->startElsewhere('orders.edit', $order->customer_id, $order->id, $line->product_id, '1');
        $this->waitUntilAnotherBackendWaitsOnALock();

        $second->table('order_shopper_assignments')->where('order_id', $order->id)->update(['started_at' => now()]);
        $second->table('orders')->where('id', $order->id)->update(['status' => 'shopping', 'shopping_started_at' => now()]);
        $second->commit();

        $outcome = $this->outcomeOf($process);
        $this->assertFalse($outcome['ok'], 'An edit landed after shopping started.');
        $this->assertSame('order_editing_locked', $outcome['code']);
        $this->assertSame('2.000', DB::table('order_items')->where('id', $line->id)->value('ordered_quantity'));
        $this->assertSame(0, DB::table('order_history')->where('order_id', $order->id)->count());
    }

    private function quietly(callable $removal): void
    {
        try {
            $removal();
        } catch (QueryException) {
            // Left behind only when the test already failed on what it checks.
        }
    }
}
