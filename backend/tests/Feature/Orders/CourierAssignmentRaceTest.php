<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\User;
use Illuminate\Database\Connection;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Tests\Support\Concurrency\RunsInAnotherProcess;
use Tests\TestCase;

/**
 * Two Courier assignments of one order, and an assignment racing a block of
 * its Courier (`DL-54` (10), `DL-62`), as `ShopperAssignmentRaceTest` proves
 * them for the Shopper.
 *
 * A second connection plays the first Operator — it holds the order, assigns
 * a Courier and commits — or the Admin blocking the Courier, and the other
 * assignment runs in another process. No test transaction wraps this class:
 * it removes what it committed. The assignment in the other process never
 * succeeds with a write here, so no append-only history row is left behind.
 */
final class CourierAssignmentRaceTest extends TestCase
{
    use RunsInAnotherProcess;

    private const SECOND = 'pgsql_second';

    /** @var list<string> */
    private array $users = [];

    private ?Order $order = null;

    private ?User $operator = null;

    protected function setUp(): void
    {
        parent::setUp();

        if (! Schema::hasTable('orders')) {
            $this->artisan('migrate');
        }

        config(['database.connections.'.self::SECOND => config('database.connections.pgsql')]);

        $this->order = Order::factory()->readyForDelivery()->create();
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

        // Each removal on its own, so one refused does not keep the others
        // from running.
        if ($this->order !== null) {
            $order = $this->order;
            $shoppers = DB::table('order_shopper_assignments')->where('order_id', $order->id)->get(['shopper_id', 'assigned_by_user_id']);
            foreach ($shoppers as $assignment) {
                $this->users[] = (string) $assignment->shopper_id;
                $this->users[] = (string) $assignment->assigned_by_user_id;
            }
            $this->quietly(static fn () => DB::table('order_courier_assignments')->where('order_id', $order->id)->delete());
            $this->quietly(static fn () => DB::table('order_shopper_assignments')->where('order_id', $order->id)->delete());
            $this->quietly(static fn () => DB::table('orders')->where('id', $order->id)->delete());
            $this->quietly(static fn () => DB::table('carts')->where('id', $order->source_cart_id)->delete());
            $this->quietly(static fn () => DB::table('customer_addresses')->where('id', $order->source_address_id)->delete());
            $this->users[] = $order->customer_id;
        }
        foreach (array_unique($this->users) as $user) {
            $this->quietly(static fn () => DB::table('users')->where('id', $user)->delete());
        }

        parent::tearDown();
    }

    public function test_an_assignment_that_waited_on_another_finds_the_order_assigned(): void
    {
        $order = $this->order ?? $this->fail('No order.');
        $first = $this->courier();
        $late = $this->courier();

        $second = $this->holdOrder($order);
        $process = $this->startElsewhere('orders.assign-courier', $this->operator()->id, $order->id, $late->id);
        $this->waitUntilAnotherBackendWaitsOnALock();
        $this->assignOn($second, $order, $first);
        $second->commit();

        $outcome = $this->outcomeOf($process);
        $this->assertFalse($outcome['ok'], 'A second Courier was assigned over the first.');
        $this->assertSame('order_state_conflict', $outcome['code']);
        $this->assertSame([$first->id], DB::table('order_courier_assignments')->where('order_id', $order->id)->pluck('courier_id')->all());
        $this->assertSame(0, DB::table('order_history')->where('order_id', $order->id)->count());
    }

    public function test_an_assignment_that_waited_on_a_block_of_its_courier_is_refused(): void
    {
        $order = $this->order ?? $this->fail('No order.');
        $courier = $this->courier();

        // The Admin's block holds the Courier's account.
        $second = DB::connection(self::SECOND);
        $second->beginTransaction();
        $second->table('users')->where('id', $courier->id)->lockForUpdate()->first();

        $process = $this->startElsewhere('orders.assign-courier', $this->operator()->id, $order->id, $courier->id);
        $this->waitUntilAnotherBackendWaitsOnALock();
        $second->table('users')->where('id', $courier->id)->update(['status' => 'blocked', 'blocked_at' => now()]);
        $second->commit();

        $outcome = $this->outcomeOf($process);
        $this->assertFalse($outcome['ok'], 'A blocked Courier was assigned.');
        $this->assertSame('staff_not_active', $outcome['code']);
        $this->assertSame('ready_for_delivery', DB::table('orders')->where('id', $order->id)->value('status'));
        $this->assertSame(0, DB::table('order_courier_assignments')->where('order_id', $order->id)->count());
    }

    private function holdOrder(Order $order): Connection
    {
        $second = DB::connection(self::SECOND);
        $second->beginTransaction();
        $second->table('orders')->where('id', $order->id)->lockForUpdate()->first();

        return $second;
    }

    /**
     * What the first assignment writes to the order, without the history row
     * this test could not remove afterwards.
     */
    private function assignOn(Connection $second, Order $order, User $courier): void
    {
        $second->table('order_courier_assignments')->insert([
            'id' => (string) Str::uuid(),
            'order_id' => $order->id,
            'courier_id' => $courier->id,
            'assigned_by_user_id' => $this->operator()->id,
            'is_self_order' => false,
            'assigned_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $second->table('orders')->where('id', $order->id)->update(['status' => 'delivery_assigned']);
    }

    private function courier(): User
    {
        $courier = User::factory()->role(Role::Courier)->create();
        $this->users[] = $courier->id;

        return $courier;
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
