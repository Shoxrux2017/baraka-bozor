<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\OrderCancellationRequest;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\Support\Concurrency\RunsInAnotherProcess;
use Tests\TestCase;

/**
 * Two Operators deciding one cancellation request at once (W3-11,
 * `DL-54` (12), `DL-65` (2)): a decision that waited on the order lock the
 * other held reads the request again under it, finds it decided, and is
 * refused — never a second, contrary decision on top.
 *
 * A second connection plays the first Operator — it holds the order, rejects
 * the request and commits, without the history row this test could not
 * remove — and the approval runs in another process. No test transaction
 * wraps this class: it removes what it committed.
 */
final class CancellationDecisionRaceTest extends TestCase
{
    use RunsInAnotherProcess;

    private const SECOND = 'pgsql_second';

    private ?OrderCancellationRequest $request = null;

    /** @var list<string> */
    private array $users = [];

    protected function setUp(): void
    {
        parent::setUp();

        if (! Schema::hasTable('order_cancellation_requests')) {
            $this->artisan('migrate');
        }

        config(['database.connections.'.self::SECOND => config('database.connections.pgsql')]);

        $order = Order::factory()->shopping()->create();
        $this->request = OrderCancellationRequest::factory()->create(['order_id' => $order->id]);
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

        if ($this->request !== null) {
            $order = Order::query()->with('shopperAssignments')->find($this->request->order_id);
            if ($order !== null) {
                $this->users = [
                    ...$this->users,
                    $order->customer_id,
                    ...$order->shopperAssignments->pluck('shopper_id')->all(),
                    ...$order->shopperAssignments->pluck('assigned_by_user_id')->all(),
                ];
                $this->quietly(static fn () => DB::table('order_cancellation_requests')->where('order_id', $order->id)->delete());
                $this->quietly(static fn () => DB::table('order_shopper_assignments')->where('order_id', $order->id)->delete());
                $this->quietly(static fn () => DB::table('orders')->where('id', $order->id)->delete());
                $this->quietly(static fn () => DB::table('carts')->where('id', $order->source_cart_id)->delete());
                $this->quietly(static fn () => DB::table('customer_addresses')->where('id', $order->source_address_id)->delete());
            }
        }
        foreach (array_unique($this->users) as $user) {
            $this->quietly(static fn () => DB::table('users')->where('id', $user)->delete());
        }

        parent::tearDown();
    }

    public function test_an_approval_that_waited_on_a_rejection_is_refused(): void
    {
        $request = $this->request ?? $this->fail('No request.');
        $first = $this->operator();
        $late = $this->operator();

        $second = DB::connection(self::SECOND);
        $second->beginTransaction();
        $second->table('orders')->where('id', $request->order_id)->lockForUpdate()->first();

        $process = $this->startElsewhere('operations.decide-cancellation', $late->id, $request->id, 'approve');
        $this->waitUntilAnotherBackendWaitsOnALock();
        $second->table('order_cancellation_requests')->where('id', $request->id)->update([
            'status' => 'rejected',
            'resolved_by_user_id' => $first->id,
            'resolved_at' => now(),
        ]);
        $second->commit();

        $outcome = $this->outcomeOf($process);
        $this->assertFalse($outcome['ok'], 'A rejected request was approved on top.');
        $this->assertSame('cancellation_request_already_decided', $outcome['code']);
        $this->assertSame('rejected', DB::table('order_cancellation_requests')->where('id', $request->id)->value('status'));
        $this->assertSame('shopping', DB::table('orders')->where('id', $request->order_id)->value('status'));
        $this->assertSame(0, DB::table('order_history')->where('order_id', $request->order_id)->count());
    }

    private function operator(): User
    {
        $operator = User::factory()->role(Role::Operator)->create();
        $this->users[] = $operator->id;

        return $operator;
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
