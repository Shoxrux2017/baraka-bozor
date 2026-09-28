<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\Enums\OrderStatus;
use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\OrderShopperAssignment;
use App\Models\User;
use Illuminate\Database\Connection;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Tests\Support\Concurrency\RunsInAnotherProcess;
use Tests\TestCase;

/**
 * A Shopper's accept or start racing the Operator's reassignment (W3-2,
 * `DL-56` (6)): the action waited on the order lock the reassignment held,
 * and must then find the order no longer the Shopper's — the scope-safe
 * `404` — rather than act on the new Shopper's assignment.
 *
 * A second connection plays the reassignment — it holds the order, ends the
 * first Shopper's assignment, makes the second's and commits, without the
 * history row this test could not remove — and the Shopper's action runs in
 * another process. No test transaction wraps this class: it removes what it
 * committed.
 */
final class ShopperReplacedRaceTest extends TestCase
{
    use RunsInAnotherProcess;

    private const SECOND = 'pgsql_second';

    private ?Order $order = null;

    private ?User $operator = null;

    /** @var list<string> */
    private array $users = [];

    protected function setUp(): void
    {
        parent::setUp();

        if (! Schema::hasTable('orders')) {
            $this->artisan('migrate');
        }

        config(['database.connections.'.self::SECOND => config('database.connections.pgsql')]);

        $this->order = Order::factory()->state(['status' => OrderStatus::ShoppingAssigned])->create();
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
            $order = $this->order;
            $this->quietly(static fn () => DB::table('order_shopper_assignments')->where('order_id', $order->id)->delete());
            $this->quietly(static fn () => DB::table('orders')->where('id', $order->id)->delete());
            $this->quietly(static fn () => DB::table('carts')->where('id', $order->source_cart_id)->delete());
            $this->quietly(static fn () => DB::table('customer_addresses')->where('id', $order->source_address_id)->delete());
            $this->users[] = $order->customer_id;
        }
        foreach ($this->users as $user) {
            $this->quietly(static fn () => DB::table('users')->where('id', $user)->delete());
        }

        parent::tearDown();
    }

    public function test_an_accept_that_waited_on_a_reassignment_is_not_found(): void
    {
        $order = $this->order ?? $this->fail('No order.');
        $replaced = $this->shopper();
        $this->assignment($replaced, accepted: false);

        $second = $this->holdOrder($order);
        $process = $this->startElsewhere('shopper.accept', $replaced->id, $order->id);
        $this->waitUntilAnotherBackendWaitsOnALock();
        $next = $this->reassignOn($second, $order, accepted: false);
        $second->commit();

        $outcome = $this->outcomeOf($process);
        $this->assertFalse($outcome['ok'], 'A replaced Shopper accepted the order.');
        $this->assertSame('resource_not_found', $outcome['code']);
        $this->assertNull(DB::table('order_shopper_assignments')->where('id', $next)->value('accepted_at'), 'The new Shopper\'s assignment was accepted for them.');
        $this->assertSame(0, DB::table('order_history')->where('order_id', $order->id)->count());
    }

    public function test_a_start_that_waited_on_a_reassignment_is_not_found(): void
    {
        $order = $this->order ?? $this->fail('No order.');
        $replaced = $this->shopper();
        $this->assignment($replaced, accepted: true);

        $second = $this->holdOrder($order);
        $process = $this->startElsewhere('shopper.start', $replaced->id, $order->id);
        $this->waitUntilAnotherBackendWaitsOnALock();
        $next = $this->reassignOn($second, $order, accepted: true);
        $second->commit();

        $outcome = $this->outcomeOf($process);
        $this->assertFalse($outcome['ok'], 'A replaced Shopper started the order.');
        $this->assertSame('resource_not_found', $outcome['code']);
        $this->assertNull(DB::table('order_shopper_assignments')->where('id', $next)->value('started_at'));
        $this->assertSame('shopping_assigned', DB::table('orders')->where('id', $order->id)->value('status'));
        $this->assertSame(0, DB::table('order_history')->where('order_id', $order->id)->count());
    }

    private function holdOrder(Order $order): Connection
    {
        $second = DB::connection(self::SECOND);
        $second->beginTransaction();
        $second->table('orders')->where('id', $order->id)->lockForUpdate()->first();

        return $second;
    }

    /**
     * What the Operator's reassignment writes, without its history row.
     */
    private function reassignOn(Connection $second, Order $order, bool $accepted): string
    {
        $second->table('order_shopper_assignments')->where('order_id', $order->id)->whereNull('ended_at')
            ->update(['ended_at' => now(), 'ended_reason' => 'reassigned']);

        $id = (string) Str::uuid();
        $second->table('order_shopper_assignments')->insert([
            'id' => $id,
            'order_id' => $order->id,
            'shopper_id' => $this->shopper()->id,
            'assigned_by_user_id' => $this->operator()->id,
            'is_self_order' => false,
            'assigned_at' => now(),
            'accepted_at' => $accepted ? now() : null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return $id;
    }

    private function assignment(User $shopper, bool $accepted): void
    {
        $order = $this->order ?? $this->fail('No order.');

        OrderShopperAssignment::factory()->create([
            'order_id' => $order->id,
            'shopper_id' => $shopper->id,
            'assigned_by_user_id' => $this->operator()->id,
            'accepted_at' => $accepted ? now() : null,
        ]);
    }

    private function shopper(): User
    {
        $shopper = User::factory()->role(Role::Shopper)->create();
        $this->users[] = $shopper->id;

        return $shopper;
    }

    private function operator(): User
    {
        if ($this->operator === null) {
            $this->operator = User::factory()->role(Role::Operator)->create();
            $this->users[] = $this->operator->id;
        }

        return $this->operator;
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
