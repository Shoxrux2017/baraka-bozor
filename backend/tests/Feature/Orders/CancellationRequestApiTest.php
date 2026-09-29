<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\CustomerApproval;
use App\Models\Enums\ApprovalStatus;
use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\CancellationReason;
use App\Models\Enums\CancellationRequestStatus;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\ItemRemovedReason;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\OrderCancellationRequest;
use App\Models\OrderCourierAssignment;
use App\Models\OrderHistory;
use App\Models\OrderItem;
use App\Models\OrderShopperAssignment;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Database\Eloquent\Factories\Factory;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * The Customer's cancellation request, the Operator's decision on it, and
 * the Operator's own cancellation after a failed delivery: `docs/09`
 * sections 22, 38, 40 and 41, `BR-CAN-002` to `BR-CAN-006`, `DL-54` (12),
 * (23) and `DL-65`.
 */
final class CancellationRequestApiTest extends TestCase
{
    use RefreshDatabase;

    private User $customer;

    private User $operator;

    protected function setUp(): void
    {
        parent::setUp();

        Carbon::setTestNow(CarbonImmutable::parse('2026-09-29T12:00:00Z'));
        $this->customer = User::factory()->customer()->create();
        $this->operator = User::factory()->role(Role::Operator)->create(['full_name' => 'Olim Operator']);
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();

        parent::tearDown();
    }

    public function test_the_customer_files_a_request_while_the_order_is_being_fulfilled(): void
    {
        $order = $this->order(Order::factory()->shopping());
        $key = (string) Str::uuid();

        $data = $this->file($order, ['reason' => 'Планы изменились'], $key)->assertOk()->json('data');

        $this->assertSame('shopping', $data['status']);
        $this->assertFalse($data['can_request_cancellation'], 'One pending request per order.');
        $request = OrderCancellationRequest::query()->where('order_id', $order->id)->sole();
        $this->assertSame([
            'id' => $request->id,
            'status' => 'pending',
            'reason' => 'Планы изменились',
            'created_at' => now()->toIso8601ZuluString(),
            'resolved_at' => null,
        ], $data['cancellation_request']);
        $row = OrderHistory::query()->where('order_id', $order->id)->sole();
        $this->assertSame([OrderHistoryEvent::CancellationRequested, null, $this->customer->id, 'Планы изменились'], [$row->event_type, $row->to_status, $row->actor_user_id, $row->note]);
        $this->assertEquals(['request_id' => $request->id], $row->details);

        // A retry with the key answers the order; a second request is refused.
        $this->assertSame($data, $this->file($order, ['reason' => 'Планы изменились'], $key)->assertOk()->json('data'));
        $this->file($order, ['reason' => 'Ещё раз'])->assertStatus(409)->assertJsonPath('code', 'cancellation_already_pending');
        $this->assertSame(1, OrderCancellationRequest::query()->count());

        // The Operator sees it, since it was filed, with the Shopper whose work it may stop.
        $items = $this->as($this->operator)->getJson('/api/v1/operations/attention')->assertOk()->json('data');
        $this->assertSame(['cancellation_request', $order->id, now()->toIso8601ZuluString()], [$items[0]['type'], $items[0]['order_id'], $items[0]['since']]);
        $this->assertSame($order->currentShopperAssignment?->shopper_id, $items[0]['shopper']['id']);
        $this->assertSame([$order->id], $this->ids(['attention' => 'cancellation_request']));
    }

    public function test_the_request_window_is_shopping_through_delivery_assigned(): void
    {
        foreach ([Order::factory()->shopping(), Order::factory()->readyForDelivery(), Order::factory()->deliveryAssigned(), Order::factory()->deliveryFailed()] as $factory) {
            $order = $this->order($factory);
            $this->customerOrder($order)->assertJsonPath('data.can_request_cancellation', true);
            $this->file($order, ['reason' => 'Не нужно'])->assertOk()->assertJsonPath('data.cancellation_request.status', 'pending');
        }

        foreach ([Order::factory()->onTheWay(), Order::factory()->completed(), Order::factory()->cancelled()] as $factory) {
            $order = $this->order($factory);
            $this->customerOrder($order)->assertJsonPath('data.can_request_cancellation', false);
            $response = $this->file($order, ['reason' => 'Не нужно']);
            $order->status === OrderStatus::Cancelled
                ? $response->assertOk()
                : $response->assertStatus(409)->assertJsonPath('code', 'order_cancellation_not_allowed');
        }

        $shopping = $this->order(Order::factory()->shopping());
        $this->file($shopping, [])->assertStatus(422)->assertJsonValidationErrors(['reason']);
        $this->file($shopping, ['reason' => '   '])->assertStatus(422)->assertJsonValidationErrors(['reason']);
        $this->file($shopping, ['reason' => str_repeat('a', 301)])->assertStatus(422)->assertJsonValidationErrors(['reason']);
        $this->assertSame(0, OrderCancellationRequest::query()->where('order_id', $shopping->id)->count());
    }

    public function test_approving_while_shopping_stops_the_shopping_and_closes_the_open_questions(): void
    {
        $order = $this->order(Order::factory()->shopping());
        $bought = OrderItem::factory()->for($order)->purchased()->create();
        $open = OrderItem::factory()->for($order)->create();
        $question = CustomerApproval::factory()->create([
            'order_item_id' => OrderItem::factory()->for($order)->awaitingCustomer()->create()->id,
            'attention_at' => now()->addMinutes(5),
            'expires_at' => now()->addMinutes(25),
        ]);
        $overdue = CustomerApproval::factory()->create([
            'order_item_id' => OrderItem::factory()->for($order)->awaitingCustomer()->create()->id,
            'attention_at' => now()->subMinutes(25),
            'expires_at' => now()->subMinutes(5),
        ]);
        $request = $this->filed($order);

        $data = $this->decide($request, ['decision' => 'approve', 'note' => 'Клиент подтвердил'])->assertOk()->json('data');

        $this->assertSame('cancelled', $data['status']);
        $this->assertSame('cancellation_request_approved', $data['cancellation_reason_code']);
        $this->assertSame('none', $data['totals']['total_kind'], 'Nothing is due (BR-CAN-006).');
        $this->assertSame(OrderItemStatus::Purchased, $bought->fresh()?->status, 'What was bought stays bought.');
        $this->assertSame([OrderItemStatus::Removed, ItemRemovedReason::OrderCancelled], [$open->fresh()?->status, $open->fresh()->removed_reason_code]);
        $this->assertSame(ApprovalStatus::Cancelled, $question->fresh()?->status);
        $this->assertSame(ApprovalStatus::Expired, $overdue->fresh()?->status, 'Expired first, as every action does (DL-54 (8)).');
        $shopper = OrderShopperAssignment::query()->where('order_id', $order->id)->sole();
        $this->assertSame(AssignmentEndReason::OrderCancelled, $shopper->ended_reason);

        $decided = $request->fresh();
        $this->assertSame([CancellationRequestStatus::Approved, $this->operator->id, 'Клиент подтвердил'], [$decided?->status, $decided->resolved_by_user_id, $decided->resolution_note]);
        $this->assertSame([
            'id' => $request->id,
            'origin' => 'customer',
            'status' => 'approved',
            'reason' => 'Планы изменились',
            'requested_by' => ['id' => $this->customer->id, 'full_name' => $this->customer->full_name],
            'created_at' => now()->toIso8601ZuluString(),
            'resolved_by' => ['id' => $this->operator->id, 'full_name' => 'Olim Operator'],
            'resolved_at' => now()->toIso8601ZuluString(),
            'resolution_note' => 'Клиент подтвердил',
        ], $data['cancellation_requests'][0]);

        $row = OrderHistory::query()->where('event_type', OrderHistoryEvent::CancellationRequestDecided)->sole();
        $this->assertSame([OrderStatus::Shopping, OrderStatus::Cancelled, CancellationReason::CancellationRequestApproved, HistoryActorType::User, 'Клиент подтвердил'], [$row->from_status, $row->to_status, $row->reason_code, $row->actor_type, $row->note]);
        $this->assertEquals(['request_id' => $request->id, 'decision' => 'approve', 'cancelled_approval_ids' => [$question->id]], $row->details);

        // The Customer sees how it ended, and the Operator's note is theirs.
        $this->customerOrder($order)->assertJsonPath('data.cancellation_request.status', 'approved')
            ->assertJsonPath('data.cancellation_request.resolved_at', now()->toIso8601ZuluString());
        $this->assertArrayNotHasKey('resolution_note', $this->customerOrder($order)->json('data.cancellation_request'));
        $this->assertSame([], $this->as($this->operator)->getJson('/api/v1/operations/attention')->json('data'));

        // The Shopper no longer reaches the order.
        $this->withToken($shopper->shopper->createToken('s')->plainTextToken)
            ->postJson("/api/v1/shopper/orders/{$order->id}/items/{$open->id}/unavailable")->assertStatus(404);
    }

    public function test_approving_after_shopping_ends_the_courier_assignment_and_keeps_the_completed_one(): void
    {
        $ready = $this->order(Order::factory()->readyForDelivery());
        $this->decide($this->filed($ready), ['decision' => 'approve'])->assertOk()->assertJsonPath('data.status', 'cancelled');
        $this->assertSame(AssignmentEndReason::Completed, OrderShopperAssignment::query()->where('order_id', $ready->id)->sole()->ended_reason);

        $assigned = $this->order(Order::factory()->deliveryAssigned());
        $courier = OrderCourierAssignment::query()->where('order_id', $assigned->id)->sole();
        $courier->forceFill(['accepted_at' => now()])->save();
        $request = $this->filed($assigned);

        // While the request waits, the Courier does not set off (DL-54 (12)).
        $this->withToken($courier->courier->createToken('c')->plainTextToken)
            ->postJson("/api/v1/courier/orders/{$assigned->id}/start")
            ->assertStatus(409)->assertJsonPath('details.reason', 'cancellation_request_pending');

        $this->decide($request, ['decision' => 'approve'])->assertOk()->assertJsonPath('data.status', 'cancelled');
        $this->assertSame(AssignmentEndReason::OrderCancelled, $courier->fresh()?->ended_reason);
        $this->assertNull($courier->fresh()->delivery_started_at);
        $this->assertSame(OrderStatus::DeliveryAssigned, OrderHistory::query()->where('order_id', $assigned->id)
            ->where('event_type', OrderHistoryEvent::CancellationRequestDecided)->sole()->from_status);
    }

    public function test_rejecting_lets_the_order_go_on_and_a_decision_stands(): void
    {
        $order = $this->order(Order::factory()->shopping());
        $request = $this->filed($order);

        $this->decide($request, ['decision' => 'reject', 'note' => 'Уже куплено'])->assertOk()->assertJsonPath('data.status', 'shopping');
        $this->assertSame([CancellationRequestStatus::Rejected, 'Уже куплено'], [$request->fresh()?->status, $request->fresh()->resolution_note]);
        $row = OrderHistory::query()->where('event_type', OrderHistoryEvent::CancellationRequestDecided)->sole();
        $this->assertSame([null, null, null, 'Уже куплено'], [$row->from_status, $row->to_status, $row->reason_code, $row->note]);
        $this->assertEquals(['request_id' => $request->id, 'decision' => 'reject'], $row->details);
        // A decided request needs no attention any more.
        $this->assertSame([], $this->ids(['attention' => 'cancellation_request']));
        $this->assertSame(0, $this->as($this->operator)->getJson('/api/v1/operations/summary')->json('data.attention_count'));

        // The same decision again is a natural repeat; the other is refused.
        $this->decide($request, ['decision' => 'reject'])->assertOk();
        $this->decide($request, ['decision' => 'approve'])->assertStatus(409)->assertJsonPath('code', 'cancellation_request_already_decided');
        $this->assertSame(1, OrderHistory::query()->where('event_type', OrderHistoryEvent::CancellationRequestDecided)->count());
        $this->assertSame(OrderStatus::Shopping, $order->fresh()?->status);

        // The Customer may ask again, and an approval then stands likewise.
        $this->customerOrder($order)->assertJsonPath('data.can_request_cancellation', true)->assertJsonPath('data.cancellation_request.status', 'rejected');
        $again = $this->filed($order);
        $this->decide($again, ['decision' => 'approve'])->assertOk();
        $this->decide($again, ['decision' => 'approve'])->assertOk();
        $this->decide($again, ['decision' => 'reject'])->assertStatus(409)->assertJsonPath('code', 'cancellation_request_already_decided');
        $this->assertSame(2, OrderHistory::query()->where('order_id', $order->id)->where('event_type', OrderHistoryEvent::CancellationRequestDecided)->count());
    }

    public function test_a_request_closes_when_the_last_line_is_removed_and_takes_no_decision(): void
    {
        $order = $this->order(Order::factory()->shopping());
        $line = OrderItem::factory()->for($order)->create();
        $request = $this->filed($order);
        $shopper = OrderShopperAssignment::query()->where('order_id', $order->id)->sole()->shopper;

        $this->withToken($shopper->createToken('s')->plainTextToken)
            ->postJson("/api/v1/shopper/orders/{$order->id}/items/{$line->id}/unavailable")->assertOk()
            ->assertJsonPath('data.status', 'cancelled');

        $this->assertSame(CancellationRequestStatus::Closed, $request->fresh()?->status);
        $this->assertSame(CancellationReason::NoItemsPurchased, $order->fresh()?->cancellation_reason_code);
        foreach (['approve', 'reject'] as $decision) {
            $this->decide($request, ['decision' => $decision])->assertStatus(409)->assertJsonPath('code', 'cancellation_request_already_decided');
        }
        $this->customerOrder($order)->assertJsonPath('data.cancellation_request.status', 'closed');
    }

    public function test_the_operator_lists_reads_and_alone_decides_the_requests(): void
    {
        $first = $this->filed($this->order(Order::factory()->shopping()));
        Carbon::setTestNow(now()->addMinute());
        $second = $this->filed($this->order(Order::factory()->readyForDelivery()));
        $this->decide($second, ['decision' => 'reject'])->assertOk();

        $all = $this->as($this->operator)->getJson('/api/v1/operations/cancellation-requests')->assertOk()->json('data');
        $this->assertSame([$second->id, $first->id], array_column($all, 'id'));
        $this->assertSame(['id', 'order', 'origin', 'status', 'reason', 'requested_by', 'created_at', 'resolved_by', 'resolved_at', 'resolution_note'], array_keys($all[0]));
        $this->assertSame(['id' => $second->order_id, 'order_number' => $second->order->order_number, 'status' => 'ready_for_delivery'], $all[0]['order']);
        $this->assertSame([$first->id], array_column($this->as($this->operator)->getJson('/api/v1/operations/cancellation-requests?status=pending')->json('data'), 'id'));
        $this->as($this->operator)->getJson('/api/v1/operations/cancellation-requests?status=maybe')->assertStatus(422);
        $this->as($this->operator)->getJson("/api/v1/operations/cancellation-requests/{$first->id}")->assertOk()->assertJsonPath('data.status', 'pending');
        $this->as($this->operator)->getJson('/api/v1/operations/cancellation-requests/'.Str::uuid())->assertStatus(404);

        $this->decide($first, ['decision' => 'maybe'])->assertStatus(422)->assertJsonValidationErrors(['decision']);
        $this->decide($first, ['decision' => 'approve', 'note' => str_repeat('a', 301)])->assertStatus(422);
        foreach ([Role::Customer, Role::Shopper, Role::Courier, Role::Manager] as $role) {
            $user = User::factory()->role($role)->create();
            $this->as($user)->getJson('/api/v1/operations/cancellation-requests')->assertStatus(403);
            $this->decide($first, ['decision' => 'approve'], $user)->assertStatus(403);
        }
        $this->decide($first, ['decision' => 'approve'], User::factory()->role(Role::Admin)->create())->assertOk();
    }

    public function test_the_operator_cancels_an_order_only_after_a_failed_delivery_and_no_request_pending(): void
    {
        $failed = $this->order(Order::factory()->deliveryFailed());
        $request = $this->filed($failed);

        $this->staffCancel($failed, ['reason_code' => 'delivery_failed'])->assertStatus(409)->assertJsonPath('code', 'cancellation_already_pending');
        $this->decide($request, ['decision' => 'reject'])->assertOk();

        $data = $this->staffCancel($failed, ['reason_code' => 'delivery_failed', 'note' => 'Не дозвонились трижды'])->assertOk()->json('data');
        $this->assertSame(['cancelled', 'delivery_failed'], [$data['status'], $data['cancellation_reason_code']]);
        $row = OrderHistory::query()->where('order_id', $failed->id)->where('event_type', OrderHistoryEvent::StatusChanged)->sole();
        $this->assertSame([OrderStatus::ReadyForDelivery, OrderStatus::Cancelled, CancellationReason::DeliveryFailed, 'Не дозвонились трижды', $this->operator->id], [$row->from_status, $row->to_status, $row->reason_code, $row->note, $row->actor_user_id]);

        // A cancelled order cancelled again is a natural repeat.
        $this->staffCancel($failed, ['reason_code' => 'delivery_failed'])->assertOk();
        $this->assertSame(1, OrderHistory::query()->where('order_id', $failed->id)->where('event_type', OrderHistoryEvent::StatusChanged)->count());

        // Only after a failed delivery.
        foreach ([Order::factory()->readyForDelivery(), Order::factory()->shopping(), Order::factory()->onTheWay(), Order::factory()->deliveryAssigned()] as $factory) {
            $this->staffCancel($this->order($factory), ['reason_code' => 'delivery_failed'])->assertStatus(409)->assertJsonPath('code', 'order_state_conflict');
        }
        $other = $this->order(Order::factory()->deliveryFailed());
        $this->staffCancel($other, ['reason_code' => 'unpaid_online'])->assertStatus(422)->assertJsonValidationErrors(['reason_code']);
        $this->staffCancel($other, [])->assertStatus(422);
        $this->staffCancel($other, ['reason_code' => 'delivery_failed'], User::factory()->role(Role::Courier)->create())->assertStatus(403);
        $this->as($this->operator)->postJson('/api/v1/operations/orders/'.Str::uuid().'/cancel', ['reason_code' => 'delivery_failed'])->assertStatus(404);
    }

    /**
     * @param  Factory<Order>  $factory
     */
    private function order(Factory $factory): Order
    {
        /** @var Order $order */
        $order = $factory->create(['customer_id' => $this->customer->id]);

        return $order;
    }

    private function filed(Order $order): OrderCancellationRequest
    {
        $this->file($order, ['reason' => 'Планы изменились'])->assertOk();

        return OrderCancellationRequest::query()->with('order')->where('order_id', $order->id)->where('status', 'pending')->sole();
    }

    /**
     * @param  array<string, mixed>  $body
     */
    private function file(Order $order, array $body, ?string $key = null): TestResponse
    {
        return $this->as($this->customer)
            ->withHeader('Idempotency-Key', $key ?? (string) Str::uuid())
            ->postJson("/api/v1/customer/orders/{$order->id}/cancel", $body);
    }

    private function customerOrder(Order $order): TestResponse
    {
        return $this->as($this->customer)->getJson("/api/v1/customer/orders/{$order->id}")->assertOk();
    }

    /**
     * @param  array<string, mixed>  $body
     */
    private function decide(OrderCancellationRequest $request, array $body, ?User $as = null): TestResponse
    {
        return $this->as($as ?? $this->operator)->postJson("/api/v1/operations/cancellation-requests/{$request->id}/decision", $body);
    }

    /**
     * @param  array<string, mixed>  $body
     */
    private function staffCancel(Order $order, array $body, ?User $as = null): TestResponse
    {
        return $this->as($as ?? $this->operator)->postJson("/api/v1/operations/orders/{$order->id}/cancel", $body);
    }

    /**
     * @param  array<string, string>  $filters
     * @return list<string>
     */
    private function ids(array $filters): array
    {
        return array_column($this->as($this->operator)->getJson('/api/v1/operations/orders?'.http_build_query($filters))->assertOk()->json('data'), 'id');
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
