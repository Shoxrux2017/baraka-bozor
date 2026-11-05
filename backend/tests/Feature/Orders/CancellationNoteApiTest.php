<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\Enums\CancellationReason;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * The reason of a direct cancel is answered on the order as
 * `cancellation_note` (`docs/09` sections 20 and 22, `DL-133` (1)).
 */
final class CancellationNoteApiTest extends TestCase
{
    use RefreshDatabase;

    private User $customer;

    private Order $order;

    protected function setUp(): void
    {
        parent::setUp();

        $this->customer = User::factory()->customer()->create();
        $this->order = Order::factory()->create(['customer_id' => $this->customer->id]);
    }

    public function test_a_direct_cancel_answers_its_reason_and_the_order_keeps_it(): void
    {
        $this->cancel($this->order, ['reason' => "  Rejam o'zgardi "])
            ->assertOk()
            ->assertJsonPath('data.cancellation_note', "Rejam o'zgardi");

        $this->detail($this->order)->assertOk()->assertJsonPath('data.cancellation_note', "Rejam o'zgardi");
    }

    public function test_a_cancel_without_a_reason_has_no_note(): void
    {
        $answer = $this->cancel($this->order)->assertOk()->json('data');

        $this->assertArrayHasKey('cancellation_note', $answer);
        $this->assertNull($answer['cancellation_note']);
        $this->assertNull($this->detail($this->order)->json('data.cancellation_note'));
    }

    public function test_a_replayed_cancel_answers_the_note_too(): void
    {
        $key = (string) Str::uuid();
        $this->cancel($this->order, ['reason' => 'Передумал'], $key)->assertOk();

        $this->cancel($this->order, ['reason' => 'Передумал'], $key)
            ->assertOk()
            ->assertJsonPath('data.cancellation_note', 'Передумал');
    }

    public function test_no_other_ending_shows_a_note(): void
    {
        $this->detail($this->order)->assertOk()->assertJsonPath('data.cancellation_note', null);

        $approved = Order::factory()->shopping()->cancelled(CancellationReason::CancellationRequestApproved)
            ->create(['customer_id' => $this->customer->id]);
        $this->writeHistory($approved, OrderHistoryEvent::CancellationRequestDecided, CancellationReason::CancellationRequestApproved, 'Клиент подтвердил');
        $this->detail($approved)->assertOk()->assertJsonPath('data.cancellation_note', null);

        $failed = Order::factory()->deliveryFailed()->cancelled(CancellationReason::DeliveryFailed)
            ->create(['customer_id' => $this->customer->id]);
        $operator = User::factory()->role(Role::Operator)->create();
        $this->writeHistory($failed, OrderHistoryEvent::StatusChanged, CancellationReason::DeliveryFailed, 'Никого нет дома', $operator);
        $this->detail($failed)->assertOk()->assertJsonPath('data.cancellation_note', null);
        $this->assertNull($failed->customerCancellation);
    }

    public function test_the_detail_reads_the_note_in_one_query(): void
    {
        $this->cancel($this->order, ['reason' => 'Передумал'])->assertOk();

        DB::enableQueryLog();
        $this->detail($this->order)->assertOk();
        $queries = array_filter(
            DB::getQueryLog(),
            static fn (array $query): bool => str_contains((string) $query['query'], 'from "order_history"')
        );
        DB::disableQueryLog();

        $this->assertCount(1, $queries);
    }

    /**
     * A history row, written as the action that owns it writes it.
     */
    private function writeHistory(Order $order, OrderHistoryEvent $event, CancellationReason $reason, string $note, ?User $actor = null): void
    {
        DB::table('order_history')->insert([
            'id' => (string) Str::uuid(),
            'order_id' => $order->id,
            'event_type' => $event->value,
            'from_status' => OrderStatus::ReadyForDelivery->value,
            'to_status' => OrderStatus::Cancelled->value,
            'actor_type' => $actor === null ? 'system' : 'user',
            'actor_user_id' => $actor?->id,
            'reason_code' => $reason->value,
            'note' => $note,
            'created_at' => now(),
        ]);
    }

    /**
     * @param  array<string, mixed>  $body
     */
    private function cancel(Order $order, array $body = [], ?string $key = null): TestResponse
    {
        return $this->asCustomer()->postJson(
            '/api/v1/customer/orders/'.$order->id.'/cancel',
            $body,
            ['Idempotency-Key' => $key ?? (string) Str::uuid()]
        );
    }

    private function detail(Order $order): TestResponse
    {
        return $this->asCustomer()->getJson('/api/v1/customer/orders/'.$order->id);
    }

    private function asCustomer(): self
    {
        return $this->withToken($this->customer->createToken('t')->plainTextToken);
    }
}
