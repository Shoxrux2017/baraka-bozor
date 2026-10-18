<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use App\Modules\Orders\CustomerCart;
use Illuminate\Database\Connection;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Tests\Support\Concurrency\RunsInAnotherProcess;
use Tests\TestCase;

/**
 * A reorder racing an add to the cart (`DL-91` item 3): the reorder waited on
 * the cart lock the add held, and must then read the cart with the add in it —
 * the product is reported in `skipped_existing_items` and the cart holds it
 * once, not twice.
 *
 * A second connection plays the add — it holds the cart, writes the line and
 * commits — and the reorder runs in another process. No test transaction wraps
 * this class: it removes what it committed.
 */
final class ReorderRaceTest extends TestCase
{
    use RunsInAnotherProcess;

    private const SECOND = 'pgsql_second';

    private ?Order $order = null;

    private ?Product $product = null;

    protected function setUp(): void
    {
        parent::setUp();

        if (! Schema::hasTable('orders')) {
            $this->artisan('migrate');
        }

        config(['database.connections.'.self::SECOND => config('database.connections.pgsql')]);

        $this->order = Order::factory()->create();
        $this->product = Product::factory()->create();
        OrderItem::factory()->for($this->order)->for($this->product)->create(['ordered_quantity' => '2.000']);
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

    public function test_a_reorder_that_waited_on_an_add_skips_the_product_the_add_put_in_the_cart(): void
    {
        $order = $this->order ?? $this->fail('No order.');
        $product = $this->product ?? $this->fail('No product.');
        $customer = $order->customer;
        $cart = CustomerCart::of($customer);

        $second = DB::connection(self::SECOND);
        $second->beginTransaction();
        $second->table('carts')->where('id', $cart->id)->lockForUpdate()->first();

        $reorder = $this->startElsewhere('customer.reorder', $customer->id, $order->id, (string) Str::uuid());
        $this->waitUntilAnotherBackendWaitsOnALock();
        $this->addTo($second, $cart->id, $product->id);
        $second->commit();

        $outcome = $this->outcomeOf($reorder);
        $this->assertTrue($outcome['ok'], 'The reorder failed: '.json_encode($outcome));
        /** @var array{added_items: list<array{product_id: string}>, skipped_existing_items: list<array{product_id: string}>} $answer */
        $answer = $outcome['answer'];
        $this->assertSame([$product->id], array_column($answer['skipped_existing_items'], 'product_id'));
        $this->assertSame([], $answer['added_items']);
        $this->assertSame(1, DB::table('cart_items')->where('cart_id', $cart->id)->where('product_id', $product->id)->count());
    }

    private function addTo(Connection $second, string $cartId, string $productId): void
    {
        $second->table('cart_items')->insert([
            'id' => (string) Str::uuid(),
            'cart_id' => $cartId,
            'product_id' => $productId,
            'quantity' => '1.000',
            'substitution_policy' => 'allow_similar_substitution',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function removeEverything(Order $order): void
    {
        $order = Order::query()->with(['items.product.category'])->find($order->id);
        if ($order === null) {
            return;
        }

        $users = array_filter([
            $order->customer_id,
            ...$order->items->map(static fn (OrderItem $item) => $item->product->created_by_user_id)->all(),
            ...$order->items->map(static fn (OrderItem $item) => $item->product->category->created_by_user_id)->all(),
        ]);

        try {
            DB::transaction(static function () use ($order): void {
                $carts = DB::table('carts')->where('customer_id', $order->customer_id)->pluck('id');
                DB::table('idempotency_keys')->where('actor_user_id', $order->customer_id)->delete();
                DB::table('cart_items')->whereIn('cart_id', $carts)->delete();
                DB::table('order_items')->where('order_id', $order->id)->delete();
                DB::table('payments')->where('order_id', $order->id)->delete();
                DB::table('order_courier_assignments')->where('order_id', $order->id)->delete();
                DB::table('order_shopper_assignments')->where('order_id', $order->id)->delete();
                DB::table('orders')->where('id', $order->id)->delete();
                DB::table('carts')->whereIn('id', $carts)->delete();
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
