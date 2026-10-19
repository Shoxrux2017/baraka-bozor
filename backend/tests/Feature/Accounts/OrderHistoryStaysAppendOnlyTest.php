<?php

declare(strict_types=1);

namespace Tests\Feature\Accounts;

use App\Models\Enums\HistoryActorType;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Order;
use App\Models\OrderHistory;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Erasure may blank the note and the details of a history row, and nothing
 * else (`DL-94` item 4); outside an erasure the table is append-only.
 */
final class OrderHistoryStaysAppendOnlyTest extends TestCase
{
    use RefreshDatabase;

    public function test_history_refuses_every_update_outside_an_erasure(): void
    {
        $row = $this->row();

        $this->assertRefused(fn () => DB::table('order_history')->where('id', $row->id)->update(['note' => null]));
        $this->assertRefused(fn () => DB::table('order_history')->where('id', $row->id)->delete());
    }

    public function test_an_erasure_may_change_only_note_and_details(): void
    {
        $row = $this->row();

        DB::transaction(function () use ($row): void {
            DB::statement("select set_config('app.customer_erasure', 'on', true)");

            DB::table('order_history')->where('id', $row->id)->update(['note' => null, 'details' => null]);
            $this->assertRefused(fn () => DB::table('order_history')->where('id', $row->id)->update(['actor_type' => 'system', 'actor_user_id' => null]));
            $this->assertRefused(fn () => DB::table('order_history')->where('id', $row->id)->delete());
        });

        $this->assertNull(OrderHistory::query()->findOrFail($row->id)->note);
    }

    private function row(): OrderHistory
    {
        $order = Order::factory()->create();
        $history = new OrderHistory;
        $history->forceFill([
            'order_id' => $order->id,
            'event_type' => OrderHistoryEvent::Edited,
            'actor_type' => HistoryActorType::User,
            'actor_user_id' => $order->customer_id,
            'note' => 'text',
            'details' => ['delivery_time_note' => ['before' => 'a', 'after' => 'b']],
        ])->save();

        return $history;
    }

    private function assertRefused(callable $statement): void
    {
        DB::statement('savepoint refused');

        try {
            $statement();
            $this->fail('The history table accepted the statement.');
        } catch (QueryException $refusal) {
            $this->assertStringContainsString('append-only', $refusal->getMessage());
        } finally {
            DB::statement('rollback to savepoint refused');
        }
    }
}
