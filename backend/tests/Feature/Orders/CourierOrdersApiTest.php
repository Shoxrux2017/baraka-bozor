<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\OrderCancellationRequest;
use App\Models\OrderCourierAssignment;
use App\Models\OrderHistory;
use App\Models\OrderShopperAssignment;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * The Courier's deliveries, accept and start: `docs/09` sections 36 and 37,
 * `docs/04` section 27, `BR-ASSIGN-003`, `BR-DEL-002`, `BR-DEL-006`,
 * `DL-54` (3), (11), (12) and `DL-63`.
 *
 * The order waits 45 minutes before a delivery counts as late, a threshold
 * snapshotted when it was placed and unlike today's setting.
 */
final class CourierOrdersApiTest extends TestCase
{
    use RefreshDatabase;

    private User $courier;

    private Order $order;

    protected function setUp(): void
    {
        parent::setUp();

        Carbon::setTestNow(CarbonImmutable::parse('2026-09-29T10:00:00Z'));
        $this->courier = User::factory()->role(Role::Courier)->create();
        $this->order = Order::factory()->deliveryAssigned()->create(['delivery_delay_threshold_minutes_snapshot' => 45]);
        $this->assignment()->forceFill(['courier_id' => $this->courier->id, 'assigned_at' => now()->subMinutes(5)])->save();
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();

        parent::tearDown();
    }

    public function test_the_list_and_the_order_show_what_the_courier_needs(): void
    {
        $data = $this->as($this->courier)->getJson('/api/v1/courier/orders')->assertOk()->json('data');

        $this->assertSame([$this->order->id], array_column($data, 'id'));
        $this->assertSame(
            ['id', 'order_number', 'status', 'recipient', 'address', 'delivery_note', 'delivery_time_note', 'payment_method', 'amount_to_collect_uzs', 'cancellation_request_pending', 'assignment', 'can_accept', 'can_start'],
            array_keys($data[0]),
        );
        $this->assertSame(['full_name' => $this->order->recipient_name_snapshot, 'phone' => $this->order->recipient_phone_snapshot], $data[0]['recipient']);
        $this->assertSame($this->order->street_snapshot, $data[0]['address']['street']);
        $this->assertSame($this->order->final_total_uzs, $data[0]['amount_to_collect_uzs'], 'Cash to collect is the final total (BR-DEL-004).');
        $this->assertFalse($data[0]['cancellation_request_pending']);
        $this->assertSame([
            'id' => $this->assignment()->id,
            'assigned_at' => now()->subMinutes(5)->toIso8601ZuluString(),
            'accepted_at' => null,
            'delivery_started_at' => null,
            'delay_at' => null,
        ], $data[0]['assignment']);
        $this->assertTrue($data[0]['can_accept']);
        $this->assertFalse($data[0]['can_start']);

        $this->assertSame($data[0], $this->as($this->courier)->getJson("/api/v1/courier/orders/{$this->order->id}")->assertOk()->json('data'));

        // The delivery the Courier has waited on longest comes first, whatever
        // the orders' numbers: the one assigned before this order was placed
        // later, and the one assigned last was placed last.
        $older = Order::factory()->deliveryAssigned()->create();
        $older->courierAssignments()->update(['courier_id' => $this->courier->id, 'assigned_at' => now()->subMinutes(30)]);
        $newest = Order::factory()->deliveryAssigned()->create();
        $newest->courierAssignments()->update(['courier_id' => $this->courier->id, 'assigned_at' => now()->subMinute()]);
        $this->assertSame(
            [$older->id, $this->order->id, $newest->id],
            array_column($this->as($this->courier)->getJson('/api/v1/courier/orders')->json('data'), 'id'),
        );
        foreach ([$older, $newest] as $other) {
            $other->courierAssignments()->update(['ended_at' => now(), 'ended_reason' => AssignmentEndReason::Reassigned->value]);
        }

        // An online order has nothing to collect.
        $online = Order::factory()->online()->deliveryAssigned()->create();
        $online->courierAssignments()->update(['courier_id' => $this->courier->id]);
        $this->as($this->courier)->getJson("/api/v1/courier/orders/{$online->id}")->assertOk()->assertJsonPath('data.amount_to_collect_uzs', null);
    }

    public function test_only_the_courier_holding_the_order_reaches_it(): void
    {
        $other = User::factory()->role(Role::Courier)->create();
        foreach (['get' => '', 'post' => '/accept'] as $method => $path) {
            $this->as($other)->json(strtoupper($method), "/api/v1/courier/orders/{$this->order->id}{$path}")->assertStatus(404);
        }
        $this->as($other)->postJson("/api/v1/courier/orders/{$this->order->id}/start")->assertStatus(404);
        $this->assertSame([], $this->as($other)->getJson('/api/v1/courier/orders')->assertOk()->json('data'));
        $this->as($this->courier)->getJson('/api/v1/courier/orders/'.Str::uuid())->assertStatus(404);

        // Replaced, the Courier no longer reaches the order (BR-ASSIGN-004).
        $this->assignment()->forceFill(['ended_at' => now(), 'ended_reason' => AssignmentEndReason::Reassigned])->save();
        OrderCourierAssignment::factory()->create(['order_id' => $this->order->id]);
        $this->as($this->courier)->getJson("/api/v1/courier/orders/{$this->order->id}")->assertStatus(404);
        $this->as($this->courier)->postJson("/api/v1/courier/orders/{$this->order->id}/accept")->assertStatus(404);
        $this->assertSame([], $this->as($this->courier)->getJson('/api/v1/courier/orders')->json('data'));
        $this->assertSame(0, OrderHistory::query()->count());

        foreach ([Role::Customer, Role::Shopper, Role::Operator, Role::Admin, Role::Manager] as $role) {
            $this->as(User::factory()->role($role)->create())->getJson('/api/v1/courier/orders')->assertStatus(403);
        }
    }

    public function test_without_a_handoff_point_the_courier_sees_the_shoppers_phone(): void
    {
        // A Shopper replaced before the shopping started is not the one to
        // call. The replaced assignment comes first, as it does in life: it is
        // made, and ended, before the one that completes the shopping.
        OrderShopperAssignment::query()->where('order_id', $this->order->id)->sole()->forceFill([
            'assigned_at' => now()->subDay(),
            'accepted_at' => null,
            'started_at' => null,
            'completed_at' => null,
            'ended_at' => now()->subHours(3),
            'ended_reason' => AssignmentEndReason::Reassigned,
        ])->save();
        $shopper = OrderShopperAssignment::factory()->ended(AssignmentEndReason::Completed)->create([
            'order_id' => $this->order->id,
            'assigned_at' => now()->subHours(2),
        ])->shopper;

        $this->assertArrayNotHasKey('shopper_phone', $this->show()->json('data'), 'With a handoff point, the Shopper is not the Courier\'s to call.');

        config(['delivery.handoff_point' => false]);
        $this->show()->assertJsonPath('data.shopper_phone', $shopper->phone);
        $this->assertSame($shopper->phone, $this->as($this->courier)->getJson('/api/v1/courier/orders')->json('data.0.shopper_phone'));
    }

    public function test_the_courier_accepts_then_starts_and_each_again_is_a_natural_repeat(): void
    {
        $this->act('start')->assertStatus(409)->assertJsonPath('code', 'delivery_state_conflict');
        $this->assertSame(OrderStatus::DeliveryAssigned, $this->order->fresh()?->status);

        $this->act('accept')->assertOk()->assertJsonPath('data.assignment.accepted_at', now()->toIso8601ZuluString())
            ->assertJsonPath('data.can_accept', false)->assertJsonPath('data.can_start', true);
        $this->act('accept')->assertOk();
        $accepted = OrderHistory::query()->where('event_type', OrderHistoryEvent::CourierAccepted)->sole();
        $this->assertSame([HistoryActorType::User, $this->courier->id], [$accepted->actor_type, $accepted->actor_user_id]);
        $this->assertEquals(['assignment_id' => $this->assignment()->id], $accepted->details);

        Carbon::setTestNow(now()->addMinutes(3));
        $data = $this->act('start')->assertOk()->json('data');

        $this->assertSame('on_the_way', $data['status']);
        $this->assertSame(now()->toIso8601ZuluString(), $data['assignment']['delivery_started_at']);
        $this->assertSame(now()->addMinutes(45)->toIso8601ZuluString(), $data['assignment']['delay_at'], 'The start plus the order\'s own threshold, not today\'s setting (BR-DEL-002).');
        $this->assertFalse($data['can_start']);
        $this->assertTrue($this->order->fresh()?->on_the_way_at?->equalTo(now()));
        $started = OrderHistory::query()->where('event_type', OrderHistoryEvent::StatusChanged)->sole();
        $this->assertSame([OrderStatus::DeliveryAssigned, OrderStatus::OnTheWay], [$started->from_status, $started->to_status]);

        Carbon::setTestNow(now()->addMinute());
        $this->act('start')->assertOk()->assertJsonPath('data.assignment.delivery_started_at', now()->subMinute()->toIso8601ZuluString());
        $this->act('accept')->assertOk();
        $this->assertSame(2, OrderHistory::query()->count());
    }

    public function test_a_pending_cancellation_request_keeps_the_courier_from_setting_off(): void
    {
        $this->act('accept')->assertOk();
        OrderCancellationRequest::factory()->create(['order_id' => $this->order->id]);

        $this->show()->assertJsonPath('data.cancellation_request_pending', true)->assertJsonPath('data.can_start', false);
        // An action's answer says so too.
        $this->act('accept')->assertOk()->assertJsonPath('data.cancellation_request_pending', true)->assertJsonPath('data.can_start', false);
        $this->act('start')
            ->assertStatus(409)
            ->assertJsonPath('code', 'delivery_state_conflict')
            ->assertJsonPath('details.reason', 'cancellation_request_pending');
        $this->assertSame(OrderStatus::DeliveryAssigned, $this->order->fresh()?->status);
        $this->assertNull($this->assignment()->delivery_started_at);

        // A rejected request no longer holds the Courier back.
        OrderCancellationRequest::query()->where('order_id', $this->order->id)->update(['status' => 'rejected', 'resolved_at' => now(), 'resolved_by_user_id' => User::factory()->role(Role::Operator)->create()->id]);
        $this->act('start')->assertOk()->assertJsonPath('data.status', 'on_the_way');
    }

    public function test_a_delivery_past_its_delay_needs_the_operators_attention(): void
    {
        $operator = User::factory()->role(Role::Operator)->create();
        $this->act('accept')->assertOk();
        $this->act('start')->assertOk();
        $delayAt = now()->addMinutes(45);

        Carbon::setTestNow($delayAt->copy()->subSecond());
        $this->assertSame([], $this->as($operator)->getJson('/api/v1/operations/attention')->json('data'));

        Carbon::setTestNow($delayAt);
        $items = $this->as($operator)->getJson('/api/v1/operations/attention')->assertOk()->json('data');
        $this->assertSame([[
            'type' => 'courier_delayed',
            'order_id' => $this->order->id,
            'order_number' => $this->order->fresh()?->order_number,
            'since' => $delayAt->toIso8601ZuluString(),
            'shopper' => null,
            'courier' => ['id' => $this->courier->id, 'full_name' => $this->courier->full_name],
        ]], $items);
        $this->assertSame([$this->order->id], array_column($this->as($operator)->getJson('/api/v1/operations/orders?attention=courier_delayed')->assertOk()->json('data'), 'id'));
        $this->assertSame(1, $this->as($operator)->getJson('/api/v1/operations/summary')->json('data.attention_count'));
    }

    private function assignment(): OrderCourierAssignment
    {
        return OrderCourierAssignment::query()->where('order_id', $this->order->id)->oldest('assigned_at')->firstOrFail();
    }

    private function show(): TestResponse
    {
        return $this->as($this->courier)->getJson("/api/v1/courier/orders/{$this->order->id}")->assertOk();
    }

    private function act(string $action): TestResponse
    {
        return $this->as($this->courier)->postJson("/api/v1/courier/orders/{$this->order->id}/{$action}");
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
