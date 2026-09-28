<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\CustomerApproval;
use App\Models\Order;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Tests\Support\Concurrency\RunsInAnotherProcess;
use Tests\TestCase;

/**
 * The Customer's decision racing the expiry (W3-5, `DL-54` (8),
 * `BR-APP-004`): a decision that waited on the order lock the expiry held
 * reads the expiry and is refused, so a late answer never counts as consent.
 *
 * A second connection plays the scheduled expiry — it holds the order, marks
 * the approval expired and commits, without the history row this test could
 * not remove — and the decision runs in another process. No test transaction
 * wraps this class: it removes what it committed, the approval with its guard
 * trigger set aside inside the removal's own transaction.
 */
final class ApprovalDecisionRaceTest extends TestCase
{
    use RunsInAnotherProcess;

    private const SECOND = 'pgsql_second';

    private ?CustomerApproval $approval = null;

    protected function setUp(): void
    {
        parent::setUp();

        if (! Schema::hasTable('customer_approvals')) {
            $this->artisan('migrate');
        }

        config(['database.connections.'.self::SECOND => config('database.connections.pgsql')]);

        $this->approval = CustomerApproval::factory()->create();
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

        if ($this->approval !== null) {
            $this->removeEverything($this->approval);
        }

        parent::tearDown();
    }

    public function test_a_decision_that_waited_on_the_expiry_is_refused(): void
    {
        $approval = $this->approval ?? $this->fail('No approval.');
        $order = $approval->order;

        $second = DB::connection(self::SECOND);
        $second->beginTransaction();
        $second->table('orders')->where('id', $order->id)->lockForUpdate()->first();

        $process = $this->startElsewhere('customer.decide', $order->customer_id, $approval->id, 'approve', (string) Str::uuid());
        $this->waitUntilAnotherBackendWaitsOnALock();

        $second->table('customer_approvals')->where('id', $approval->id)->update(['status' => 'expired']);
        $second->commit();

        $outcome = $this->outcomeOf($process);
        $this->assertFalse($outcome['ok'], 'A decision landed on an expired approval.');
        $this->assertSame('approval_expired', $outcome['code']);
        $this->assertSame('expired', DB::table('customer_approvals')->where('id', $approval->id)->value('status'));
        $this->assertNull(DB::table('customer_approvals')->where('id', $approval->id)->value('resolution'));
        $this->assertSame('awaiting_customer', DB::table('order_items')->where('id', $approval->order_item_id)->value('status'));
        $this->assertSame(0, DB::table('order_history')->where('order_id', $order->id)->count());
    }

    private function removeEverything(CustomerApproval $approval): void
    {
        $order = Order::query()->with(['shopperAssignments', 'items.product.category'])->find($approval->order_id);
        if ($order === null) {
            return;
        }

        $users = array_filter([
            $order->customer_id,
            ...$order->shopperAssignments->pluck('shopper_id')->all(),
            ...$order->shopperAssignments->pluck('assigned_by_user_id')->all(),
            ...$order->items->map(static fn ($item) => $item->product->created_by_user_id)->all(),
            ...$order->items->map(static fn ($item) => $item->product->category->created_by_user_id)->all(),
        ]);

        try {
            DB::transaction(static function () use ($order): void {
                DB::statement('alter table customer_approvals disable trigger customer_approvals_guard');
                DB::table('customer_approvals')->where('order_id', $order->id)->delete();
                DB::statement('alter table customer_approvals enable trigger customer_approvals_guard');
                DB::table('idempotency_keys')->where('actor_user_id', $order->customer_id)->delete();
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
