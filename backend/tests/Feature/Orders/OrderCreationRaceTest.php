<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\BusinessSettings;
use App\Models\CartItem;
use App\Models\Category;
use App\Models\CustomerAddress;
use App\Models\Enums\PaymentMethod;
use App\Models\Product;
use App\Models\User;
use App\Modules\Orders\Actions\PreviewCheckout;
use App\Modules\Orders\CustomerCart;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Tests\Support\Concurrency\RunsInAnotherProcess;
use Tests\TestCase;

/**
 * Two creations from one cart make one order (`DL-37` (7), W2-5): the second,
 * waiting on the cart lock while the first converts the cart, finds the
 * Customer's new cart instead, and its token is stale — no second order, and
 * its idempotency key is gone so a retry is judged again.
 *
 * A second connection plays the first creation — it holds the cart and
 * converts it — and the second creation runs in another process. No test
 * transaction wraps this class: it restores the settings it changed first and
 * removes what it committed. When the test passes no order is committed; were
 * one committed, its append-only history could not be removed, and the next
 * `migrate:fresh` of the test database takes it.
 */
final class OrderCreationRaceTest extends TestCase
{
    use RunsInAnotherProcess;

    private const SECOND = 'pgsql_second';

    /** @var array<string, mixed> */
    private array $settingsBefore = [];

    private ?User $customer = null;

    private ?Product $product = null;

    protected function setUp(): void
    {
        parent::setUp();

        if (! Schema::hasTable('orders')) {
            $this->artisan('migrate');
        }

        config(['database.connections.'.self::SECOND => config('database.connections.pgsql')]);

        $this->settingsBefore = (array) DB::table('business_settings')->where('id', BusinessSettings::SINGLETON_ID)->first();
        DB::table('business_settings')->where('id', BusinessSettings::SINGLETON_ID)->update([
            'markup_percent' => '15.00',
            'service_fee_mode' => 'fixed',
            'service_fee_fixed_uzs' => 5000,
            'service_fee_percent' => null,
            'delivery_fee_uzs' => 15000,
            'minimum_order_uzs' => 0,
            'opens_at' => '00:00',
            'closes_at' => '23:59',
            'service_centre_latitude' => '41.311081',
            'service_centre_longitude' => '69.240562',
            'service_radius_km' => '5.00',
        ]);

        $this->customer = User::factory()->customer()->create(['full_name' => 'Aziza Karimova']);
        $this->product = Product::factory()->create();
    }

    protected function tearDown(): void
    {
        // The settings first: a later test in this run must never see the race's.
        if ($this->settingsBefore !== []) {
            DB::table('business_settings')->where('id', BusinessSettings::SINGLETON_ID)->update($this->settingsBefore);
        }

        if (config()->has('database.connections.'.self::SECOND)) {
            $second = DB::connection(self::SECOND);
            while ($second->transactionLevel() > 0) {
                $second->rollBack();
            }
            DB::purge(self::SECOND);
        }

        // Each removal on its own, so one refused — a committed order holds its
        // cart, and its append-only history cannot be removed at all — does not
        // keep the others from running.
        $users = [];
        if ($this->customer !== null) {
            $customer = $this->customer->id;
            $carts = DB::table('carts')->where('customer_id', $customer)->pluck('id');
            $this->quietly(static fn () => DB::table('idempotency_keys')->where('actor_user_id', $customer)->delete());
            $this->quietly(static fn () => DB::table('cart_items')->whereIn('cart_id', $carts)->delete());
            $this->quietly(static fn () => DB::table('carts')->whereIn('id', $carts)->delete());
            $this->quietly(static fn () => DB::table('customer_addresses')->where('customer_id', $customer)->delete());
            $users[] = $customer;
        }
        if ($this->product !== null) {
            $product = $this->product;
            $category = Category::query()->find($product->category_id);
            $this->quietly(static fn () => DB::table('products')->where('id', $product->id)->delete());
            $users[] = $product->created_by_user_id;
            if ($category !== null) {
                $this->quietly(static fn () => DB::table('categories')->where('id', $category->id)->delete());
                $users[] = $category->created_by_user_id;
            }
        }
        foreach ($users as $user) {
            $this->quietly(static fn () => DB::table('users')->where('id', $user)->delete());
        }

        parent::tearDown();
    }

    private function quietly(callable $removal): void
    {
        try {
            $removal();
        } catch (QueryException) {
            // Left behind only when the test already failed on what it checks.
        }
    }

    public function test_a_creation_that_waited_on_another_from_the_same_cart_is_stale(): void
    {
        $customer = $this->customer ?? $this->fail('No customer.');
        $address = CustomerAddress::factory()->create(['customer_id' => $customer->id]);
        $cart = CustomerCart::of($customer);
        CartItem::factory()->create(['cart_id' => $cart->id, 'product_id' => $this->product?->id, 'quantity' => '3.000']);
        $token = (new PreviewCheckout)->preview($customer, $address->id, PaymentMethod::Cash, null)->token->token;

        // The first creation holds the cart.
        $second = DB::connection(self::SECOND);
        $second->beginTransaction();
        $second->table('carts')->where('id', $cart->id)->lockForUpdate()->first();

        $late = $this->startElsewhere('orders.create', $customer->id, $token, (string) Str::uuid());
        $this->waitUntilAnotherBackendWaitsOnALock();

        // ... converts the cart, opens the new one, and commits.
        $second->table('carts')->where('id', $cart->id)->update(['status' => 'converted']);
        $second->table('carts')->insert([
            'id' => (string) Str::uuid(),
            'customer_id' => $customer->id,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $second->commit();

        $outcome = $this->outcomeOf($late);
        $this->assertFalse($outcome['ok'], 'A second order was created from one cart.');
        $this->assertSame('checkout_snapshot_stale', $outcome['code']);
        $this->assertSame(0, DB::table('orders')->where('customer_id', $customer->id)->count());
        $this->assertSame(0, DB::table('idempotency_keys')->where('actor_user_id', $customer->id)->count());
    }
}
