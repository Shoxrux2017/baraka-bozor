<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Exceptions\ApiException;
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
use Illuminate\Support\Str;
use LogicException;
use Tests\Support\Concurrency\RunsInAnotherProcess;
use Tests\TestCase;

/**
 * `DL-37` (7) and `DL-40` (5): every cart change takes the cart lock first,
 * so it lands before an order is created from the cart or after it, in the
 * new cart — never across it, and never lost.
 *
 * Proven with real commits: a second connection holds the lock the way order
 * creation will, and where a change must wait while that connection converts
 * the cart, the change runs in another process (`RunsInAnotherProcess`). No
 * test transaction wraps this class, so it removes what it committed.
 */
final class CartLockTest extends TestCase
{
    use RunsInAnotherProcess;

    private const SECOND = 'pgsql_second';

    private const LOCK_NOT_AVAILABLE = '55P03';

    private ?User $customer = null;

    private ?Product $product = null;

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
        $second = DB::connection(self::SECOND);
        while ($second->transactionLevel() > 0) {
            $second->rollBack();
        }
        DB::purge(self::SECOND);
        DB::statement('reset lock_timeout');

        $users = [];
        if ($this->customer !== null) {
            $carts = DB::table('carts')->where('customer_id', $this->customer->id)->pluck('id');
            DB::table('cart_items')->whereIn('cart_id', $carts)->delete();
            DB::table('carts')->whereIn('id', $carts)->delete();
            $users[] = $this->customer->id;
        }
        if ($this->product !== null) {
            $category = Category::query()->find($this->product->category_id);
            DB::table('products')->where('id', $this->product->id)->delete();
            $users[] = $this->product->created_by_user_id;
            if ($category !== null) {
                DB::table('categories')->where('id', $category->id)->delete();
                $users[] = $category->created_by_user_id;
            }
        }
        DB::table('users')->whereIn('id', $users)->delete();

        parent::tearDown();
    }

    public function test_a_change_that_waited_on_an_order_creation_lands_in_the_new_cart(): void
    {
        $cart = CustomerCart::of($this->customer());

        $second = $this->second();
        $second->beginTransaction();
        $second->table('carts')->where('id', $cart->id)->lockForUpdate()->first();

        $change = $this->startElsewhere('cart.add', $this->customer()->id, $this->product()->id);
        $this->waitUntilAnotherBackendWaitsOnALock();

        // As order creation does: convert the cart, open a new one, commit.
        $second->table('carts')->where('id', $cart->id)->update(['status' => 'converted']);
        $newCart = (string) Str::uuid();
        $second->table('carts')->insert([
            'id' => $newCart,
            'customer_id' => $this->customer()->id,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $second->commit();

        $outcome = $this->outcomeOf($change);
        $this->assertTrue($outcome['ok'], 'The change was lost: '.json_encode($outcome));
        $this->assertSame($newCart, $outcome['cart_id']);
        $this->assertSame(0, DB::table('cart_items')->where('cart_id', $cart->id)->count(), 'Nothing reached the converted cart.');
        $this->assertSame(1, DB::table('cart_items')->where('cart_id', $newCart)->count());
    }

    public function test_two_first_accesses_make_one_cart(): void
    {
        // The first access has inserted its cart and not yet committed.
        $second = $this->second();
        $second->beginTransaction();
        $pending = (string) Str::uuid();
        $second->table('carts')->insert([
            'id' => $pending,
            'customer_id' => $this->customer()->id,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::statement("set lock_timeout = '300ms'");
        $this->assertWaits(fn () => CustomerCart::of($this->customer()));

        $second->commit();

        $this->assertSame($pending, CustomerCart::of($this->customer())->id);
        $this->assertSame(1, Cart::query()->where('customer_id', $this->customer()->id)->count());
    }

    public function test_two_adds_of_one_product_make_one_line_and_the_second_is_told_which(): void
    {
        $cart = CustomerCart::of($this->customer());

        // The first add holds the cart and has written its line, uncommitted.
        $second = $this->second();
        $second->beginTransaction();
        $second->table('carts')->where('id', $cart->id)->lockForUpdate()->first();
        $line = (string) Str::uuid();
        $second->table('cart_items')->insert([
            'id' => $line,
            'cart_id' => $cart->id,
            'product_id' => $this->product()->id,
            'quantity' => '1.000',
            'substitution_policy' => 'allow_similar_substitution',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::statement("set lock_timeout = '300ms'");
        $this->assertWaits(fn () => $this->add());

        $second->commit();

        try {
            $this->add();
            $this->fail('The product is already in the cart.');
        } catch (ApiException $refusal) {
            $this->assertSame('cart_item_already_exists', $refusal->apiCode());
            $this->assertSame(['cart_item_id' => $line], $refusal->details());
        }
        $this->assertSame(1, DB::table('cart_items')->where('cart_id', $cart->id)->count());
    }

    public function test_a_change_and_a_removal_wait_on_the_cart_lock(): void
    {
        $cart = $this->add();
        $line = (string) DB::table('cart_items')->where('cart_id', $cart->id)->value('id');

        $second = $this->second();
        $second->beginTransaction();
        $second->table('carts')->where('id', $cart->id)->lockForUpdate()->first();

        DB::statement("set lock_timeout = '300ms'");
        $this->assertWaits(fn () => (new ChangeCart)->update($this->customer(), $line, ['quantity' => '2']));
        $this->assertWaits(fn () => (new ChangeCart)->remove($this->customer(), $line));

        $second->commit();

        (new ChangeCart)->remove($this->customer(), $line);
        $this->assertSame(0, DB::table('cart_items')->where('cart_id', $cart->id)->count());
    }

    private function add(): Cart
    {
        return (new ChangeCart)->add($this->customer(), ['product_id' => $this->product()->id, 'quantity' => '1']);
    }

    private function customer(): User
    {
        return $this->customer ?? throw new LogicException('No customer.');
    }

    private function product(): Product
    {
        return $this->product ?? throw new LogicException('No product.');
    }

    private function second(): Connection
    {
        return DB::connection(self::SECOND);
    }

    private function assertWaits(callable $statement): void
    {
        try {
            $statement();
            $this->fail('The statement did not wait for the other connection.');
        } catch (QueryException $timeout) {
            $this->assertSame(self::LOCK_NOT_AVAILABLE, $timeout->getCode(), $timeout->getMessage());
        }
    }
}
