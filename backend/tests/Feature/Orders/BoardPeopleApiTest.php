<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\OrderCourierAssignment;
use App\Models\OrderItem;
use App\Models\OrderShopperAssignment;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * Who a board row names, the self-order mark, and blocked staff on the
 * attention list: `docs/09` section 38, `BR-ASSIGN-005`, `DL-54` (13), (14)
 * and `DL-62`.
 */
final class BoardPeopleApiTest extends TestCase
{
    use RefreshDatabase;

    private const PHONE = '+998901234567';

    private User $operator;

    private User $customer;

    protected function setUp(): void
    {
        parent::setUp();

        Carbon::setTestNow(CarbonImmutable::parse('2026-09-29T09:00:00Z'));
        $this->operator = User::factory()->role(Role::Operator)->create();
        $this->customer = User::factory()->customer()->create(['phone' => self::PHONE]);
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();

        parent::tearDown();
    }

    public function test_a_self_order_keeps_its_mark_and_its_shopper_once_the_shopping_is_done(): void
    {
        $order = Order::factory()->shopping()->create(['customer_id' => $this->customer->id]);
        $shopper = User::factory()->role(Role::Shopper)->create(['phone' => self::PHONE, 'full_name' => 'Self Shopper']);
        $order->shopperAssignments()->update(['shopper_id' => $shopper->id, 'is_self_order' => true, 'assigned_at' => now()->subHour()]);
        $line = OrderItem::factory()->for($order)->create();
        $shopperApi = $this->withToken($shopper->createToken('s')->plainTextToken)->withHeader('Idempotency-Key', (string) Str::uuid());
        $shopperApi->postJson("/api/v1/shopper/orders/{$order->id}/items/{$line->id}/purchase", ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 16000])->assertOk();
        $shopperApi->withHeader('Idempotency-Key', (string) Str::uuid())->postJson("/api/v1/shopper/orders/{$order->id}/complete")->assertOk();

        $row = $this->row($order);
        $this->assertSame('ready_for_delivery', $row['status']);
        $this->assertTrue($row['is_self_order'], 'The audit flag outlives the assignment (DL-54 (14)).');
        $this->assertSame(['id' => $shopper->id, 'full_name' => 'Self Shopper'], $row['shopper'], 'The one who completed the shopping.');
        $this->assertNull($row['courier']);
        $this->assertSame([$order->id], $this->ids(['shopper_id' => $shopper->id]));
        $this->assertSame([$order->id], $this->ids(['attention' => 'self_order']));

        $item = $this->attention()[0];
        $this->assertSame(['self_order', $order->id, now()->subHour()->toIso8601ZuluString()], [$item['type'], $item['order_id'], $item['since']]);
        $this->assertSame($shopper->id, $item['shopper']['id']);
    }

    public function test_an_order_several_assignments_mark_is_one_item_since_the_first_naming_the_latest(): void
    {
        $order = Order::factory()->deliveryAssigned()->create(['customer_id' => $this->customer->id]);
        $shopper = OrderShopperAssignment::query()->where('order_id', $order->id)->sole();
        $shopper->forceFill(['is_self_order' => true, 'assigned_at' => now()->subHour()])->save();
        $first = OrderCourierAssignment::query()->where('order_id', $order->id)->sole();
        $first->forceFill([
            'is_self_order' => true,
            'assigned_at' => now()->subMinutes(30),
            'accepted_at' => now()->subMinutes(29),
            'ended_at' => now()->subMinutes(20),
            'ended_reason' => AssignmentEndReason::Reassigned,
        ])->save();
        $latest = OrderCourierAssignment::factory()->create(['order_id' => $order->id, 'is_self_order' => true, 'assigned_at' => now()->subMinutes(10)]);

        $items = $this->attention();

        $this->assertCount(1, $items);
        $this->assertSame(['self_order', now()->subHour()->toIso8601ZuluString()], [$items[0]['type'], $items[0]['since']]);
        $this->assertSame($shopper->shopper_id, $items[0]['shopper']['id']);
        $this->assertSame($latest->courier_id, $items[0]['courier']['id'], 'The latest of the Couriers marking it.');
    }

    public function test_a_self_order_assignment_replaced_before_work_stops_marking_the_order(): void
    {
        $order = Order::factory()->shoppingAssigned()->create(['customer_id' => $this->customer->id]);
        $order->shopperAssignments()->update(['is_self_order' => true, 'accepted_at' => now()]);
        $order->shopperAssignments()->update(['ended_at' => now(), 'ended_reason' => AssignmentEndReason::Reassigned->value]);
        OrderShopperAssignment::factory()->create(['order_id' => $order->id]);

        $this->assertFalse($this->row($order)['is_self_order']);
        $this->assertSame([], $this->ids(['attention' => 'self_order']));

        // A Courier who accepted and was then replaced still marks it.
        $delivering = Order::factory()->deliveryAssigned()->create(['customer_id' => $this->customer->id]);
        $delivering->courierAssignments()->update([
            'is_self_order' => true,
            'accepted_at' => now(),
            'ended_at' => now(),
            'ended_reason' => AssignmentEndReason::Reassigned->value,
        ]);
        OrderCourierAssignment::factory()->create(['order_id' => $delivering->id]);
        $this->assertTrue($this->row($delivering)['is_self_order']);
    }

    public function test_a_self_order_courier_whose_delivery_failed_still_marks_the_order_the_row_no_longer_names(): void
    {
        $order = Order::factory()->deliveryFailed()->create(['customer_id' => $this->customer->id]);
        $courier = OrderCourierAssignment::query()->where('order_id', $order->id)->sole();
        $courier->forceFill(['is_self_order' => true])->save();

        $row = $this->row($order);
        $this->assertTrue($row['is_self_order']);
        $this->assertNull($row['courier'], 'The row names the current Courier or the one who delivered, not one who failed.');
        $this->assertSame([], $this->ids(['courier_id' => $courier->courier_id]));

        $detail = $this->as($this->operator)->getJson("/api/v1/operations/orders/{$order->id}")->json('data.courier_assignments.0');
        $this->assertSame([$courier->id, true, 'delivery_failed'], [$detail['id'], $detail['is_self_order'], $detail['ended_reason']]);

        $item = $this->attention()[0];
        $this->assertSame('self_order', $item['type']);
        $this->assertSame($courier->courier_id, $item['courier']['id']);
    }

    public function test_a_cancelled_self_order_keeps_its_mark_but_leaves_the_attention_list(): void
    {
        $order = Order::factory()->shopping()->cancelled()->create(['customer_id' => $this->customer->id]);
        $order->shopperAssignments()->update(['is_self_order' => true]);

        $row = $this->row($order);
        $this->assertTrue($row['is_self_order'], 'A self-order Shopper whose shopping was cancelled is what the flag exists to show.');
        $this->assertNull($row['shopper']);
        $this->assertSame([], $this->attention());
        $this->assertSame([], $this->ids(['attention' => 'self_order']));
    }

    public function test_the_courier_filter_matches_the_courier_the_row_names(): void
    {
        $current = Order::factory()->deliveryAssigned()->create();
        $delivered = Order::factory()->completed()->create();
        $currentCourier = OrderCourierAssignment::query()->where('order_id', $current->id)->sole()->courier_id;
        $deliveredBy = OrderCourierAssignment::query()->where('order_id', $delivered->id)->sole();
        $completedShopper = OrderShopperAssignment::query()->where('order_id', $delivered->id)->sole()->shopper_id;

        $this->assertSame([$current->id], $this->ids(['courier_id' => $currentCourier]));
        $this->assertSame([$delivered->id], $this->ids(['courier_id' => strtoupper($deliveredBy->courier_id)]));
        $this->assertSame([$delivered->id], $this->ids(['shopper_id' => $completedShopper]));
        $this->assertSame([], $this->ids(['courier_id' => (string) Str::uuid()]));
        $this->as($this->operator)->getJson('/api/v1/operations/orders?courier_id=nope')->assertStatus(422)->assertJsonValidationErrors(['courier_id']);

        $this->assertSame($deliveredBy->courier_id, $this->row($delivered)['courier']['id'] ?? null);
    }

    public function test_an_open_order_whose_current_shopper_or_courier_is_blocked_needs_attention(): void
    {
        $shopping = Order::factory()->shopping()->create();
        $shopper = OrderShopperAssignment::query()->where('order_id', $shopping->id)->sole()->shopper;
        $delivering = Order::factory()->deliveryAssigned()->create();
        $courier = OrderCourierAssignment::query()->where('order_id', $delivering->id)->sole()->courier;
        $closed = Order::factory()->completed()->create();
        $closedCourier = OrderCourierAssignment::query()->where('order_id', $closed->id)->sole()->courier;
        // Open, but its blocked Shopper finished the shopping: nothing waits
        // on them any more.
        $shopped = Order::factory()->readyForDelivery()->create();
        OrderShopperAssignment::query()->where('order_id', $shopped->id)->sole()->shopper
            ->forceFill(['status' => 'blocked', 'blocked_at' => now()->subMinutes(40)])->save();

        $shopper->forceFill(['status' => 'blocked', 'blocked_at' => now()->subMinutes(20)])->save();
        $courier->forceFill(['status' => 'blocked', 'blocked_at' => now()->subMinutes(5)])->save();
        $closedCourier->forceFill(['status' => 'blocked', 'blocked_at' => now()->subMinutes(30)])->save();

        $items = $this->attention();
        $this->assertSame([
            ['staff_blocked', $shopping->id, now()->subMinutes(20)->toIso8601ZuluString()],
            ['staff_blocked', $delivering->id, now()->subMinutes(5)->toIso8601ZuluString()],
        ], array_map(static fn (array $item): array => [$item['type'], $item['order_id'], $item['since']], $items));
        $this->assertSame([$shopper->id, null], [$items[0]['shopper']['id'], $items[0]['courier']]);
        $this->assertSame([null, $courier->id], [$items[1]['shopper'], $items[1]['courier']['id']]);
        $this->assertEqualsCanonicalizing([$shopping->id, $delivering->id], $this->ids(['attention' => 'staff_blocked']));
        $this->assertSame(2, $this->as($this->operator)->getJson('/api/v1/operations/summary')->json('data.attention_count'));

        // Reassigned to an active Courier, the order needs nothing more.
        $replacement = User::factory()->role(Role::Courier)->create();
        $this->as($this->operator)->putJson("/api/v1/operations/orders/{$delivering->id}/courier-assignment", [
            'courier_id' => $replacement->id,
            'replaces_assignment_id' => OrderCourierAssignment::query()->where('order_id', $delivering->id)->whereNull('ended_at')->sole()->id,
        ])->assertOk();
        $this->assertSame([$shopping->id], $this->ids(['attention' => 'staff_blocked']));
    }

    /**
     * @return array<string, mixed>
     */
    private function row(Order $order): array
    {
        $rows = collect($this->as($this->operator)->getJson('/api/v1/operations/orders')->assertOk()->json('data'))->keyBy('id');

        return $rows[$order->id];
    }

    /**
     * @param  array<string, string>  $filters
     * @return list<string>
     */
    private function ids(array $filters): array
    {
        return array_column($this->as($this->operator)->getJson('/api/v1/operations/orders?'.http_build_query($filters))->assertOk()->json('data'), 'id');
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function attention(): array
    {
        return $this->as($this->operator)->getJson('/api/v1/operations/attention')->assertOk()->json('data');
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
