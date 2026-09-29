<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\DeliveryFailureReason;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\PaymentMethod;
use App\Models\Enums\PaymentProvider;
use App\Models\Enums\PaymentStatus;
use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\OrderCourierAssignment;
use App\Models\OrderHistory;
use App\Models\Payment;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * Delivered and not delivered: `docs/09` section 37, `docs/04` sections 28 and
 * 29, `BR-DEL-003`, `BR-DEL-004`, `BR-PAY-003`, `DL-54` (3), (11), (23),
 * `DL-55` (13) and `DL-64`.
 *
 * The factory's shopped order totals 120 000 UZS.
 */
final class DeliveryOutcomeApiTest extends TestCase
{
    use RefreshDatabase;

    private const TOTAL = 120000;

    private User $courier;

    private Order $order;

    protected function setUp(): void
    {
        parent::setUp();

        Carbon::setTestNow(CarbonImmutable::parse('2026-09-29T11:00:00Z'));
        $this->courier = User::factory()->role(Role::Courier)->create(['full_name' => 'Kamol Courier']);
        $this->order = Order::factory()->onTheWay()->create([
            'ready_for_delivery_at' => now()->subHour(),
            'apartment_snapshot' => '12',
            'landmark_snapshot' => 'Напротив школы',
            'delivery_note_snapshot' => 'Позвонить у подъезда',
            'delivery_time_note' => 'после 18:00',
        ]);
        $this->assignment()->forceFill(['courier_id' => $this->courier->id])->save();
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();

        parent::tearDown();
    }

    public function test_delivered_records_the_cash_and_completes_the_order(): void
    {
        // While the Courier holds the delivery, the order says who, where and when.
        $held = $this->as($this->courier)->getJson("/api/v1/courier/orders/{$this->order->id}")->assertOk()->json('data');
        $this->assertSame(['full_name' => $this->order->recipient_name_snapshot, 'phone' => $this->order->recipient_phone_snapshot], $held['recipient']);
        $this->assertSame(['12', 'Напротив школы'], [$held['address']['apartment'], $held['address']['landmark']]);
        $this->assertSame(['Позвонить у подъезда', 'после 18:00'], [$held['delivery_note'], $held['delivery_time_note']]);

        $data = $this->delivered(['cash_received_uzs' => self::TOTAL])->assertOk()->json('data');

        $this->assertSame('completed', $data['status']);
        $this->assertSame($this->assignment()->id, $data['assignment']['id']);

        $payment = Payment::query()->where('order_id', $this->order->id)->sole();
        $this->assertSame(
            [PaymentMethod::Cash, PaymentStatus::Paid, self::TOTAL, $this->courier->id, null],
            [$payment->method, $payment->status, $payment->amount_uzs, $payment->recorded_by_user_id, $payment->provider],
        );
        $this->assertTrue($payment->paid_at?->equalTo(now()));

        $order = $this->order->fresh();
        $this->assertSame(OrderStatus::Completed, $order?->status);
        $this->assertTrue($order->completed_at?->equalTo(now()));
        $assignment = $this->assignment();
        $this->assertSame(AssignmentEndReason::Completed, $assignment->ended_reason);
        $this->assertTrue($assignment->completed_at?->equalTo(now()));

        $row = OrderHistory::query()->where('order_id', $this->order->id)->sole();
        $this->assertSame(OrderHistoryEvent::PaymentRecorded, $row->event_type);
        $this->assertSame([OrderStatus::OnTheWay, OrderStatus::Completed], [$row->from_status, $row->to_status]);
        $this->assertSame($this->courier->id, $row->actor_user_id);
        $this->assertEquals(['assignment_id' => $assignment->id, 'payment_id' => $payment->id, 'method' => 'cash', 'amount_uzs' => self::TOTAL], $row->details);

        // The Customer, the board and the summary read the payment.
        $customer = User::query()->findOrFail($this->order->customer_id);
        $this->as($customer)->getJson("/api/v1/customer/orders/{$this->order->id}")->assertOk()->assertJsonPath('data.payment', [
            'method' => 'cash',
            'status' => 'paid',
            'amount_uzs' => self::TOTAL,
            'paid_at' => now()->toIso8601ZuluString(),
        ]);
        $operator = User::factory()->role(Role::Operator)->create();
        $this->as($operator)->getJson("/api/v1/operations/orders/{$this->order->id}")->assertOk()->assertJsonPath('data.payment', [
            'id' => $payment->id,
            'method' => 'cash',
            'provider' => null,
            'status' => 'paid',
            'amount_uzs' => self::TOTAL,
            'paid_at' => now()->toIso8601ZuluString(),
            'recorded_by' => ['id' => $this->courier->id, 'full_name' => 'Kamol Courier'],
        ]);
        $summary = $this->as($operator)->getJson('/api/v1/operations/summary')->assertOk()->json('data');
        $this->assertSame([1, self::TOTAL], [$summary['completed_today'], $summary['sales_today_uzs']]);
        $this->assertSame(['id' => $this->courier->id, 'full_name' => 'Kamol Courier'], $this->as($operator)->getJson('/api/v1/operations/orders')->json('data.0.courier'), 'The one who delivered.');
    }

    public function test_the_cash_must_be_the_final_total(): void
    {
        $key = (string) Str::uuid();

        $this->delivered([], $key)->assertStatus(422)->assertJsonValidationErrors(['cash_received_uzs']);
        $this->delivered(['cash_received_uzs' => '120000'], $key)->assertStatus(422)->assertJsonValidationErrors(['cash_received_uzs']);
        $this->delivered(['cash_received_uzs' => self::TOTAL - 1], $key)
            ->assertStatus(409)
            ->assertJsonPath('code', 'cash_amount_mismatch')
            ->assertJsonPath('details', ['expected_uzs' => self::TOTAL]);
        $this->delivered(['cash_received_uzs' => self::TOTAL + 1000], $key)->assertStatus(409)->assertJsonPath('code', 'cash_amount_mismatch');

        $this->assertSame(OrderStatus::OnTheWay, $this->order->fresh()?->status);
        $this->assertSame(0, Payment::query()->count());
        $this->assertSame(0, OrderHistory::query()->count());

        // A refusal frees the key (DL-39 (2)).
        $this->delivered(['cash_received_uzs' => self::TOTAL], $key)->assertOk()->assertJsonPath('data.status', 'completed');
    }

    public function test_a_replay_answers_through_the_ended_assignment_while_it_is_the_latest(): void
    {
        $key = (string) Str::uuid();
        $first = $this->delivered(['cash_received_uzs' => self::TOTAL], $key)->assertOk()->json();

        $this->assertSame($first, $this->delivered(['cash_received_uzs' => self::TOTAL], $key)->assertOk()->json());
        $this->assertSame(1, Payment::query()->count());
        $this->assertSame(1, OrderHistory::query()->count());
        $this->delivered(['cash_received_uzs' => self::TOTAL - 1], $key)->assertStatus(409)->assertJsonPath('code', 'idempotency_key_reused');

        // Delivered again with a new key is a natural repeat (docs/09 section
        // 49, BR-CON-005): the order as it is, and no second payment.
        $this->delivered(['cash_received_uzs' => self::TOTAL])->assertOk()->assertJsonPath('data.status', 'completed');
        $this->assertSame(1, Payment::query()->count());
        $this->assertSame(1, OrderHistory::query()->count());
        // Another Courier's is not.
        $this->delivered(['cash_received_uzs' => self::TOTAL], as: User::factory()->role(Role::Courier)->create())->assertStatus(404);

        // The outcome, not the recipient: the delivery is no longer the Courier's.
        $this->assertNull($first['data']['recipient']);
        $this->assertNull($first['data']['address']);
        $this->assertNull($first['data']['delivery_note']);
        $this->assertNull($first['data']['delivery_time_note']);
        config(['delivery.handoff_point' => false]);
        $this->assertArrayNotHasKey('shopper_phone', $this->delivered(['cash_received_uzs' => self::TOTAL], $key)->assertOk()->json('data'));

        // A read needs a current assignment.
        $this->as($this->courier)->getJson("/api/v1/courier/orders/{$this->order->id}")->assertStatus(404);
        $this->assertSame([], $this->as($this->courier)->getJson('/api/v1/courier/orders')->json('data'));

        // Once a later Courier assignment exists, the replay no longer reaches it.
        OrderCourierAssignment::factory()->create(['order_id' => $this->order->id, 'assigned_at' => now()->addMinute()]);
        $this->delivered(['cash_received_uzs' => self::TOTAL], $key)->assertStatus(404);
    }

    public function test_only_a_delivery_that_set_off_is_delivered(): void
    {
        $this->assignment()->forceFill(['courier_id' => User::factory()->role(Role::Courier)->create()->id])->save();
        $this->delivered(['cash_received_uzs' => self::TOTAL])->assertStatus(404);
        $this->assignment()->forceFill(['courier_id' => $this->courier->id])->save();

        $waiting = Order::factory()->deliveryAssigned()->create();
        $waiting->courierAssignments()->update(['courier_id' => $this->courier->id, 'accepted_at' => now()]);
        $this->delivered(['cash_received_uzs' => self::TOTAL], order: $waiting)->assertStatus(409)->assertJsonPath('code', 'delivery_state_conflict');
        $this->notDelivered(['reason_code' => 'no_answer'], $waiting)->assertStatus(409)->assertJsonPath('code', 'delivery_state_conflict');

        // An order cancelled while the Courier held it is not theirs to
        // answer: only a failure they recorded is repeated.
        $cancelled = Order::factory()->deliveryAssigned()->cancelled()->create();
        $cancelled->courierAssignments()->update(['courier_id' => $this->courier->id]);
        $this->notDelivered(['reason_code' => 'no_answer'], $cancelled)->assertStatus(404);

        // No online order is on its way before Wave 5 (DL-54 (1)); one met here
        // is not completed unpaid.
        $online = Order::factory()->online()->onTheWay()->create();
        $online->courierAssignments()->update(['courier_id' => $this->courier->id]);
        $this->delivered([], order: $online)->assertStatus(409)->assertJsonPath('code', 'delivery_state_conflict');

        $this->flushHeaders();
        $this->as($this->courier)->postJson("/api/v1/courier/orders/{$this->order->id}/delivered", ['cash_received_uzs' => self::TOTAL])
            ->assertStatus(400)->assertJsonPath('code', 'idempotency_key_required');
        foreach ([Role::Customer, Role::Shopper, Role::Operator] as $role) {
            $this->delivered(['cash_received_uzs' => self::TOTAL], as: User::factory()->role($role)->create())->assertStatus(403);
        }
        $this->assertSame(0, Payment::query()->count());
    }

    public function test_not_delivered_returns_the_order_to_the_operator_who_assigns_another_courier(): void
    {
        $readyAt = $this->order->fresh()?->ready_for_delivery_at;
        Carbon::setTestNow(now()->addMinutes(20));

        $data = $this->notDelivered(['reason_code' => 'no_answer'])->assertOk()->json('data');

        $this->assertSame('ready_for_delivery', $data['status']);
        $order = $this->order->fresh();
        $this->assertNull($order?->on_the_way_at, 'Cleared, and set again by the next start (DL-55 (13)).');
        $this->assertTrue($order->ready_for_delivery_at?->equalTo($readyAt), 'The first readiness is kept.');
        $failed = $this->assignment();
        $this->assertSame([AssignmentEndReason::DeliveryFailed, DeliveryFailureReason::NoAnswer, null], [$failed->ended_reason, $failed->failed_reason_code, $failed->failed_note]);
        $row = OrderHistory::query()->where('order_id', $this->order->id)->sole();
        $this->assertSame(OrderHistoryEvent::DeliveryFailed, $row->event_type);
        $this->assertSame([OrderStatus::OnTheWay, OrderStatus::ReadyForDelivery], [$row->from_status, $row->to_status]);
        $this->assertEquals(['assignment_id' => $failed->id, 'reason_code' => 'no_answer'], $row->details);

        // A repeat answers the order as it is and writes nothing, whatever its
        // reason, telling the outcome but not the recipient any more.
        $this->notDelivered(['reason_code' => 'no_answer'])->assertOk()->assertJsonPath('data.status', 'ready_for_delivery')
            ->assertJsonPath('data.recipient', null)->assertJsonPath('data.address', null);
        $this->assertNull($data['recipient'], 'The first answer already ended the assignment.');
        // No other Courier reaches it that way.
        $this->notDelivered(['reason_code' => 'no_answer'], as: User::factory()->role(Role::Courier)->create())->assertStatus(404);
        $this->notDelivered(['reason_code' => 'refused'])->assertOk();
        $this->assertSame(1, OrderHistory::query()->count());
        $this->assertSame(DeliveryFailureReason::NoAnswer, $this->assignment()->failed_reason_code);

        // The Operator sees it, since the failure, naming the Courier.
        $operator = User::factory()->role(Role::Operator)->create();
        $this->assertSame([[
            'type' => 'delivery_failed',
            'order_id' => $this->order->id,
            'order_number' => $order->order_number,
            'since' => now()->toIso8601ZuluString(),
            'shopper' => null,
            'courier' => ['id' => $this->courier->id, 'full_name' => 'Kamol Courier'],
        ]], $this->as($operator)->getJson('/api/v1/operations/attention')->json('data'));
        $this->assertSame([$this->order->id], array_column($this->as($operator)->getJson('/api/v1/operations/orders?attention=delivery_failed')->json('data'), 'id'));

        // Assigned again, the order leaves the list, and the failed Courier's
        // repeat no longer reaches it.
        $next = User::factory()->role(Role::Courier)->create();
        $this->as($operator)->postJson("/api/v1/operations/orders/{$this->order->id}/courier-assignment", ['courier_id' => $next->id])->assertOk();
        $this->assertSame([], $this->as($operator)->getJson('/api/v1/operations/attention')->json('data'));
        $this->notDelivered(['reason_code' => 'no_answer'])->assertStatus(404);

        // The next Courier delivers it.
        $this->as($next)->postJson("/api/v1/courier/orders/{$this->order->id}/accept")->assertOk();
        $this->as($next)->postJson("/api/v1/courier/orders/{$this->order->id}/start")->assertOk();
        $this->assertTrue($this->order->fresh()?->on_the_way_at?->equalTo(now()));
        $this->delivered(['cash_received_uzs' => self::TOTAL], as: $next)->assertOk()->assertJsonPath('data.status', 'completed');
        $this->assertSame($next->id, Payment::query()->where('order_id', $this->order->id)->sole()->recorded_by_user_id);
    }

    public function test_a_second_failure_is_the_one_that_counts(): void
    {
        $operator = User::factory()->role(Role::Operator)->create();
        $this->notDelivered(['reason_code' => 'no_answer'])->assertOk();

        Carbon::setTestNow(now()->addMinutes(30));
        $next = User::factory()->role(Role::Courier)->create(['full_name' => 'Botir Courier']);
        $this->as($operator)->postJson("/api/v1/operations/orders/{$this->order->id}/courier-assignment", ['courier_id' => $next->id])->assertOk();
        $this->as($next)->postJson("/api/v1/courier/orders/{$this->order->id}/accept")->assertOk();
        $this->as($next)->postJson("/api/v1/courier/orders/{$this->order->id}/start")->assertOk();
        Carbon::setTestNow(now()->addMinutes(15));
        $this->notDelivered(['reason_code' => 'refused'], as: $next)->assertOk();

        // The first Courier's failure is no longer the order's latest.
        $this->notDelivered(['reason_code' => 'no_answer'])->assertStatus(404);
        $this->notDelivered(['reason_code' => 'refused'], as: $next)->assertOk();

        $this->assertSame([[
            'type' => 'delivery_failed',
            'order_id' => $this->order->id,
            'order_number' => $this->order->fresh()?->order_number,
            'since' => now()->toIso8601ZuluString(),
            'shopper' => null,
            'courier' => ['id' => $next->id, 'full_name' => 'Botir Courier'],
        ]], $this->as($operator)->getJson('/api/v1/operations/attention')->json('data'));
    }

    public function test_the_orders_show_the_live_payment_not_a_cancelled_one(): void
    {
        // As in life, the cancelled payment came first and the paid one after.
        $order = Order::factory()->online()->completedWithoutPayment()->create();
        Payment::factory()->create([
            'order_id' => $order->id,
            'method' => PaymentMethod::Online,
            'provider' => PaymentProvider::Payme,
            'amount_uzs' => $order->final_total_uzs,
            'status' => PaymentStatus::Cancelled,
            'cancelled_at' => now()->subHour(),
            'paid_at' => null,
            'recorded_by_user_id' => null,
        ]);
        $paid = Payment::factory()->create([
            'order_id' => $order->id,
            'method' => PaymentMethod::Online,
            'provider' => PaymentProvider::Payme,
            'amount_uzs' => $order->final_total_uzs,
            'status' => PaymentStatus::Paid,
            'paid_at' => now(),
            'recorded_by_user_id' => null,
        ]);

        $customer = User::query()->findOrFail($order->customer_id);
        $this->as($customer)->getJson("/api/v1/customer/orders/{$order->id}")->assertOk()->assertJsonPath('data.payment.status', 'paid');
        $this->as(User::factory()->role(Role::Admin)->create())->getJson("/api/v1/operations/orders/{$order->id}")
            ->assertOk()->assertJsonPath('data.payment.id', $paid->id);
    }

    public function test_not_delivered_takes_a_known_reason_and_a_note_with_other(): void
    {
        $this->notDelivered([])->assertStatus(422)->assertJsonValidationErrors(['reason_code']);
        $this->notDelivered(['reason_code' => 'lost'])->assertStatus(422)->assertJsonValidationErrors(['reason_code']);
        $this->notDelivered(['reason_code' => 'other'])->assertStatus(422)->assertJsonValidationErrors(['note']);
        $this->notDelivered(['reason_code' => 'other', 'note' => '   '])->assertStatus(422)->assertJsonValidationErrors(['note']);
        $this->notDelivered(['reason_code' => 'refused', 'note' => str_repeat('a', 301)])->assertStatus(422)->assertJsonValidationErrors(['note']);
        $this->notDelivered(['reason_code' => 'refused', 'extra' => true])->assertStatus(422);
        $this->assertSame(OrderStatus::OnTheWay, $this->order->fresh()?->status);

        $this->notDelivered(['reason_code' => 'other', 'note' => 'Подъезд закрыт'])->assertOk();
        $this->assertSame([DeliveryFailureReason::Other, 'Подъезд закрыт'], [$this->assignment()->failed_reason_code, $this->assignment()->failed_note]);
        $this->assertSame('Подъезд закрыт', OrderHistory::query()->sole()->note);
    }

    private function assignment(): OrderCourierAssignment
    {
        return OrderCourierAssignment::query()->where('order_id', $this->order->id)->oldest('assigned_at')->oldest('id')->firstOrFail();
    }

    /**
     * @param  array<string, mixed>  $body
     */
    private function delivered(array $body, ?string $key = null, ?User $as = null, ?Order $order = null): TestResponse
    {
        return $this->as($as ?? $this->courier)
            ->withHeader('Idempotency-Key', $key ?? (string) Str::uuid())
            ->postJson('/api/v1/courier/orders/'.($order ?? $this->order)->id.'/delivered', $body);
    }

    /**
     * @param  array<string, mixed>  $body
     */
    private function notDelivered(array $body, ?Order $order = null, ?User $as = null): TestResponse
    {
        return $this->as($as ?? $this->courier)->postJson('/api/v1/courier/orders/'.($order ?? $this->order)->id.'/not-delivered', $body);
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
