<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\Cart;
use App\Models\Category;
use App\Models\Product;
use App\Models\User;
use App\Modules\Orders\Actions\ChangeCart;
use App\Modules\Orders\CustomerCart;
use Illuminate\Database\Connection;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

/**
 * `DL-37` (7): every cart change takes the cart lock first, so a change lands
 * before an order is created from the cart or after it, never across it.
 * Proven with real commits and a second connection holding the lock, the way
 * order creation will hold it; no test transaction wraps this class, so it
 * cleans up what it committed.
 */
final class CartLockTest extends TestCase
{
    private const SECOND = 'pgsql_second';

    private User $customer;

    private Product $product;

    protected function setUp(): void
    {
        parent::setUp();

        if (! Schema::hasTable('cart_items')) {
            $this->artisan('migrate');
        }

        config(['database.connections.'.self::SECOND => config('database.connections.pgsql')]);

        $this->customer = User::factory()->customer()->create();
        $this->product = Product::factory()->create();
    }

    protected function tearDown(): void
    {
        $second = $this->second();
        while ($second->transactionLevel() > 0) {
            $second->rollBack();
        }
        DB::purge(self::SECOND);
        DB::statement('reset lock_timeout');

        $cartIds = DB::table('carts')->where('customer_id', $this->customer->id)->pluck('id');
        DB::table('cart_items')->whereIn('cart_id', $cartIds)->delete();
        DB::table('carts')->whereIn('id', $cartIds)->delete();
        $category = Category::query()->findOrFail($this->product->category_id);
        DB::table('products')->where('id', $this->product->id)->delete();
        DB::table('categories')->where('id', $category->id)->delete();
        DB::table('users')->whereIn('id', [$this->customer->id, $this->product->created_by_user_id, $category->created_by_user_id])->delete();

        parent::tearDown();
    }

    public function test_a_cart_change_waits_while_another_transaction_holds_the_cart(): void
    {
        $cart = CustomerCart::of($this->customer);

        // As order creation will: lock the cart and hold it.
        $second = $this->second();
        $second->beginTransaction();
        $second->table('carts')->where('id', $cart->id)->lockForUpdate()->first();

        DB::statement("set lock_timeout = '300ms'");
        try {
            (new ChangeCart)->add($this->customer, ['product_id' => $this->product->id, 'quantity' => '1']);
            $this->fail('The change did not wait for the cart lock.');
        } catch (QueryException $timeout) {
            $this->assertSame('55P03', $timeout->getCode());
        }

        $second->commit();

        $changed = (new ChangeCart)->add($this->customer, ['product_id' => $this->product->id, 'quantity' => '1']);
        $this->assertSame($cart->id, $changed->id);
        $this->assertSame(1, $this->second()->table('cart_items')->where('cart_id', $cart->id)->count());
    }

    public function test_two_first_accesses_make_one_cart(): void
    {
        $first = CustomerCart::of($this->customer);
        $second = CustomerCart::of($this->customer);

        $this->assertSame($first->id, $second->id);
        $this->assertSame(1, Cart::query()->where('customer_id', $this->customer->id)->count());
    }

    private function second(): Connection
    {
        return DB::connection(self::SECOND);
    }
}
