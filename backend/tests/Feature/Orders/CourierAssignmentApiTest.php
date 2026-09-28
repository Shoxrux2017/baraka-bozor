<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\OrderCourierAssignment;
use App\Models\OrderHistory;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * The Courier picker and the Courier assignment, `docs/09` section 39,
 * `docs/04` section 26, `BR-ASSIGN-001`, `BR-ASSIGN-002`, `DL-54` (10) and
 * `DL-62`.
 */
final class CourierAssignmentApiTest extends TestCase
{
    use RefreshDatabase;

    private User $operator;

    protected function setUp(): void
    {
        parent::setUp();

        $this->operator = User::factory()->role(Role::Operator)->create(['full_name' => 'Olim Operator']);
    }

    public function test_only_the_operator_and_the_admin_pick_and_assign(): void
    {
        $courier = $this->courier();

        $admin = User::factory()->role(Role::Admin)->create();
        $this->as($admin)->getJson('/api/v1/operations/couriers')->assertOk();
        $this->assign(Order::factory()->readyForDelivery()->create(), $courier, $admin)->assertOk();

        foreach ([Role::Customer, Role::Shopper, Role::Courier, Role::Manager] as $role) {
            $user = User::factory()->role($role)->create();
            $order = Order::factory()->readyForDelivery()->create();
            $this->as($user)->getJson('/api/v1/operations/couriers')->assertStatus(403);
            $this->assign($order, $courier, $user)->assertStatus(403);
            $this->assign($order, $courier, $user, 'put')->assertStatus(403);
        }
    }

    public function test_the_picker_lists_active_couriers_by_name_with_the_orders_in_their_hands(): void
    {
        // Byte order would put the capital B first; the name order ignores case.
        $bobur = $this->courier('Bobur Aliyev');
        $aziz = $this->courier('aziz Karimov');
        $this->courier('Blocked Courier', blocked: true);
        User::factory()->role(Role::Shopper)->create(['full_name' => 'A Shopper']);
        OrderCourierAssignment::factory()->create(['courier_id' => $bobur->id]);
        OrderCourierAssignment::factory()->started()->create(['courier_id' => $bobur->id]);
        OrderCourierAssignment::factory()->ended(AssignmentEndReason::Completed)->create(['courier_id' => $aziz->id]);

        $response = $this->as($this->operator)->getJson('/api/v1/operations/couriers')->assertOk();

        $this->assertSame([$aziz->id, $bobur->id], array_column($response->json('data'), 'id'));
        $this->assertSame(
            ['id' => $aziz->id, 'full_name' => 'aziz Karimov', 'phone' => $aziz->phone, 'current_assignment_count' => 0],
            $response->json('data.0')
        );
        $this->assertSame(2, $response->json('data.1.current_assignment_count'));
        $this->assertSame(2, $response->json('meta.pagination.total'));
    }

    public function test_an_assignment_moves_a_ready_order_to_delivery_assigned_with_one_history_row(): void
    {
        $order = Order::factory()->readyForDelivery()->create();
        $courier = $this->courier();

        $data = $this->assign($order, $courier)->assertOk()->json('data');

        $this->assertSame('delivery_assigned', $data['status']);
        $this->assertCount(1, $data['courier_assignments']);
        $assignment = $data['courier_assignments'][0];
        $this->assertSame(
            ['id', 'courier', 'assigned_by', 'is_self_order', 'assigned_at', 'accepted_at', 'delivery_started_at', 'delay_at', 'completed_at', 'ended_at', 'ended_reason', 'failed_reason_code', 'failed_note'],
            array_keys($assignment)
        );
        $this->assertSame(['id' => $courier->id, 'full_name' => $courier->full_name, 'phone' => $courier->phone], $assignment['courier']);
        $this->assertSame(['id' => $this->operator->id, 'full_name' => 'Olim Operator'], $assignment['assigned_by']);
        $this->assertFalse($assignment['is_self_order']);
        $this->assertNull($assignment['accepted_at']);
        $this->assertNull($assignment['ended_at']);

        $this->assertCount(1, $data['history']);
        $history = $data['history'][0];
        $this->assertSame('courier_assigned', $history['event_type']);
        $this->assertSame('ready_for_delivery', $history['from_status']);
        $this->assertSame('delivery_assigned', $history['to_status']);
        $this->assertSame($this->operator->id, $history['actor']['id']);
        $this->assertEquals(
            ['assignment_id' => $assignment['id'], 'courier_id' => $courier->id, 'is_self_order' => false],
            $history['details']
        );

        // The board's row names the Courier.
        $row = $this->as($this->operator)->getJson('/api/v1/operations/orders')->assertOk()->json('data.0');
        $this->assertSame(['id' => $courier->id, 'full_name' => $courier->full_name], $row['courier']);
    }

    public function test_the_current_courier_again_is_a_natural_repeat(): void
    {
        $order = Order::factory()->readyForDelivery()->create();
        $courier = $this->courier();
        $this->assign($order, $courier)->assertOk();

        $this->assign($order, $courier)->assertOk()->assertJsonPath('data.status', 'delivery_assigned');
        $this->assign($order, $courier, method: 'put')->assertOk();
        // The id in capitals is the same Courier.
        $this->postBody($order, ['courier_id' => strtoupper($courier->id)])->assertOk();

        $this->assertSame(1, OrderCourierAssignment::query()->where('order_id', $order->id)->count());
        $this->assertSame(1, OrderHistory::query()->where('order_id', $order->id)->count());
    }

    public function test_a_reassignment_before_the_courier_sets_off_ends_the_current_assignment(): void
    {
        $order = Order::factory()->deliveryAssigned()->create();
        $first = $this->currentAssignmentOf($order);
        $first?->forceFill(['accepted_at' => now()])->save();
        $second = $this->courier();

        $data = $this->assign($order, $second, method: 'put')->assertOk()->json('data');

        $this->assertSame('delivery_assigned', $data['status']);
        $this->assertSame([$first?->id, $data['courier_assignments'][1]['id']], array_column($data['courier_assignments'], 'id'));
        $this->assertSame('reassigned', $data['courier_assignments'][0]['ended_reason']);
        $this->assertNotNull($data['courier_assignments'][0]['ended_at']);
        $this->assertSame($second->id, $data['courier_assignments'][1]['courier']['id']);

        $history = $data['history'][0];
        $this->assertSame('courier_reassigned', $history['event_type']);
        $this->assertNull($history['from_status']);
        $this->assertNull($history['to_status']);
        $this->assertEquals([
            'assignment_id' => $data['courier_assignments'][1]['id'],
            'courier_id' => $second->id,
            'is_self_order' => false,
            'previous_assignment_id' => $first?->id,
            'previous_courier_id' => $first?->courier_id,
        ], $history['details']);
    }

    public function test_the_courier_must_be_an_active_couriers_account(): void
    {
        $order = Order::factory()->readyForDelivery()->create();

        foreach ([
            User::factory()->role(Role::Shopper)->create(),
            User::factory()->role(Role::Operator)->create(),
            User::factory()->customer()->create(),
        ] as $notACourier) {
            $this->assign($order, $notACourier)->assertStatus(422)->assertJsonPath('code', 'validation_failed')
                ->assertJsonValidationErrors(['courier_id']);
        }
        $this->postBody($order, ['courier_id' => (string) Str::uuid()])->assertStatus(422)->assertJsonValidationErrors(['courier_id']);
        $this->postBody($order, ['courier_id' => 'not-a-uuid'])->assertStatus(422)->assertJsonValidationErrors(['courier_id']);
        $this->postBody($order, [])->assertStatus(422)->assertJsonValidationErrors(['courier_id']);
        $this->postBody($order, ['courier_id' => $this->courier()->id, 'is_self_order' => true])->assertStatus(422);

        $this->assign($order, $this->courier(blocked: true))->assertStatus(409)->assertJsonPath('code', 'staff_not_active');

        $this->assertSame('ready_for_delivery', $order->fresh()?->status->value);
        $this->assertSame(0, OrderCourierAssignment::query()->where('order_id', $order->id)->count());
        $this->assertSame(0, OrderHistory::query()->where('order_id', $order->id)->count());
    }

    public function test_a_blocked_courier_is_refused_before_the_repeat_and_the_order_state(): void
    {
        $order = Order::factory()->readyForDelivery()->create();
        $courier = $this->courier();
        $this->assign($order, $courier)->assertOk();
        $courier->forceFill(['status' => 'blocked', 'blocked_at' => now()])->save();

        // A Courier blocked since is not a repeat: the Operator must reassign.
        $this->assign($order, $courier)->assertStatus(409)->assertJsonPath('code', 'staff_not_active');
        $this->assign($order, $courier, method: 'put')->assertStatus(409)->assertJsonPath('code', 'staff_not_active');
        $this->assign(Order::factory()->create(), $courier)->assertStatus(409)->assertJsonPath('code', 'staff_not_active');
        $this->assertSame(1, OrderCourierAssignment::query()->where('order_id', $order->id)->count());
        $this->assertSame(1, OrderHistory::query()->where('order_id', $order->id)->count());

        // The way out: the Operator reassigns the order to an active Courier.
        $blocked = $this->currentAssignmentOf($order);
        $data = $this->assign($order, $this->courier(), method: 'put')->assertOk()->json('data');
        $this->assertSame([$blocked?->id, 'reassigned'], [$data['courier_assignments'][0]['id'], $data['courier_assignments'][0]['ended_reason']]);
    }

    public function test_a_stale_or_retried_reassignment_never_undoes_a_newer_one(): void
    {
        $order = Order::factory()->readyForDelivery()->create();
        [$a, $b, $c] = [$this->courier('A'), $this->courier('B'), $this->courier('C')];
        $this->assign($order, $a)->assertOk();
        $first = $this->currentAssignmentOf($order)?->id;

        // One Operator moves the order from A to B.
        $this->assign($order, $b, method: 'put', replaces: $first)->assertOk();
        $second = $this->currentAssignmentOf($order)?->id;
        // Another, whose board still shows A, is refused and reloads.
        $this->assign($order, $c, method: 'put', replaces: $first)->assertStatus(409)->assertJsonPath('code', 'order_state_conflict');
        // The first Operator's retry is a natural repeat.
        $this->assign($order, $b, method: 'put', replaces: $first)->assertOk();

        // Once the order has moved on to C, the same retry is refused, not a move back to B.
        $this->assign($order, $c, method: 'put', replaces: $second)->assertOk();
        $this->assign($order, $b, method: 'put', replaces: $first)->assertStatus(409)->assertJsonPath('code', 'order_state_conflict');

        $this->assertSame($c->id, $this->currentAssignmentOf($order)?->courier_id);
        $this->assertSame(3, OrderCourierAssignment::query()->where('order_id', $order->id)->count());
        $this->assertSame(3, OrderHistory::query()->where('order_id', $order->id)->count());
    }

    public function test_a_reassignment_names_the_assignment_it_replaces_and_an_assignment_does_not(): void
    {
        $order = Order::factory()->deliveryAssigned()->create();
        $courier = $this->courier();
        $url = '/api/v1/operations/orders/'.$order->id.'/courier-assignment';

        $this->as($this->operator)->putJson($url, ['courier_id' => $courier->id])
            ->assertStatus(422)->assertJsonValidationErrors(['replaces_assignment_id']);
        $this->as($this->operator)->putJson($url, ['courier_id' => $courier->id, 'replaces_assignment_id' => 'nope'])
            ->assertStatus(422)->assertJsonValidationErrors(['replaces_assignment_id']);
        $this->postBody(Order::factory()->readyForDelivery()->create(), ['courier_id' => $courier->id, 'replaces_assignment_id' => (string) Str::uuid()])
            ->assertStatus(422);
        // The id in capitals is the same assignment.
        $this->as($this->operator)->putJson($url, [
            'courier_id' => $courier->id,
            'replaces_assignment_id' => strtoupper((string) $this->currentAssignmentOf($order)?->id),
        ])->assertOk();
    }

    public function test_an_order_in_another_state_is_a_conflict(): void
    {
        $courier = $this->courier();
        $orders = [
            'new' => Order::factory()->create(),
            'shopping' => Order::factory()->shopping()->create(),
            'on the way' => Order::factory()->onTheWay()->create(),
            'completed' => Order::factory()->completed()->create(),
            'cancelled' => Order::factory()->readyForDelivery()->cancelled()->create(),
        ];

        foreach ($orders as $name => $order) {
            $this->assign($order, $courier)->assertStatus(409)->assertJsonPath('code', 'order_state_conflict');
            $this->assign($order, $courier, method: 'put')->assertStatus(409)->assertJsonPath('code', 'order_state_conflict');
            $this->assertSame(0, OrderHistory::query()->where('order_id', $order->id)->count(), $name);
        }
        // An order with a Courier is reassigned, not assigned again, whatever
        // its status says.
        $assigned = Order::factory()->deliveryAssigned()->create();
        $this->assign($assigned, $courier)->assertStatus(409)->assertJsonPath('code', 'order_state_conflict');
        $held = Order::factory()->readyForDelivery()->create();
        OrderCourierAssignment::factory()->create(['order_id' => $held->id]);
        $this->assign($held, $courier)->assertStatus(409)->assertJsonPath('code', 'order_state_conflict');
        // A ready order has no Courier to replace.
        $this->assign(Order::factory()->readyForDelivery()->create(), $courier, method: 'put')
            ->assertStatus(409)->assertJsonPath('code', 'order_state_conflict');
        // A Courier who set off keeps the order even before it shows `on_the_way` (`BR-ASSIGN-002`).
        $setOff = Order::factory()->deliveryAssigned()->create();
        $this->currentAssignmentOf($setOff)?->forceFill(['accepted_at' => now(), 'delivery_started_at' => now(), 'delay_at' => now()->addHour()])->save();
        $this->assign($setOff, $courier, method: 'put')->assertStatus(409)->assertJsonPath('code', 'order_state_conflict');

        $this->postBody(Order::factory()->readyForDelivery()->make(['id' => (string) Str::uuid()]), ['courier_id' => $courier->id])->assertStatus(404);
        $this->assertSame(0, OrderCourierAssignment::query()->where('courier_id', $courier->id)->count());
    }

    public function test_an_order_back_after_a_failed_delivery_takes_a_courier_again(): void
    {
        $order = Order::factory()->deliveryFailed()->create();
        $failed = OrderCourierAssignment::query()->where('order_id', $order->id)->sole();
        $courier = $this->courier();

        $data = $this->assign($order, $courier)->assertOk()->json('data');

        $this->assertSame('delivery_assigned', $data['status']);
        $this->assertSame([$failed->id, 'delivery_failed'], [$data['courier_assignments'][0]['id'], $data['courier_assignments'][0]['ended_reason']]);
        $this->assertSame('no_answer', $data['courier_assignments'][0]['failed_reason_code']);
        $this->assertSame($courier->id, $data['courier_assignments'][1]['courier']['id']);
        $this->assertSame('courier_assigned', $data['history'][0]['event_type']);
    }

    public function test_a_courier_with_the_customers_phone_is_a_self_order(): void
    {
        $customer = User::factory()->customer()->create(['phone' => '+998901234567']);
        $order = Order::factory()->readyForDelivery()->create(['customer_id' => $customer->id]);
        $self = User::factory()->role(Role::Courier)->create(['phone' => '+998901234567']);

        $data = $this->assign($order, $self)->assertOk()->json('data');

        $this->assertTrue($data['courier_assignments'][0]['is_self_order']);
        $this->assertTrue($data['history'][0]['details']['is_self_order']);
        $this->as($this->operator)->getJson('/api/v1/operations/orders')->assertJsonPath('data.0.is_self_order', true);
        $item = $this->as($this->operator)->getJson('/api/v1/operations/attention')->json('data.0');
        $this->assertSame(['self_order', $order->id], [$item['type'], $item['order_id']]);
        $this->assertSame(['id' => $self->id, 'full_name' => $self->full_name], $item['courier']);
        $this->assertNull($item['shopper']);

        // Replaced before accepting, the Courier no longer marks the order (DL-54 (14)).
        $this->assign($order, $this->courier(), method: 'put')->assertOk();
        $this->as($this->operator)->getJson('/api/v1/operations/orders')->assertJsonPath('data.0.is_self_order', false);
        $this->assertSame([], $this->as($this->operator)->getJson('/api/v1/operations/attention')->json('data'));
    }

    private function courier(string $name = 'Kamol Courier', bool $blocked = false): User
    {
        $factory = User::factory()->role(Role::Courier);

        return ($blocked ? $factory->blocked() : $factory)->create(['full_name' => $name]);
    }

    /**
     * A `PUT` replaces [$replaces], by default the order's current assignment
     * as the Operator would have seen it.
     */
    private function assign(Order $order, User $courier, ?User $as = null, string $method = 'post', ?string $replaces = null): TestResponse
    {
        $body = ['courier_id' => $courier->id];
        if ($method === 'put') {
            $body['replaces_assignment_id'] = $replaces
                ?? $this->currentAssignmentOf($order)->id
                ?? (string) Str::uuid();
        }

        return $this->as($as ?? $this->operator)->json(
            strtoupper($method),
            '/api/v1/operations/orders/'.$order->id.'/courier-assignment',
            $body,
        );
    }

    private function currentAssignmentOf(Order $order): ?OrderCourierAssignment
    {
        return OrderCourierAssignment::query()->where('order_id', $order->id)->whereNull('ended_at')->first();
    }

    /**
     * @param  array<string, mixed>  $body
     */
    private function postBody(Order $order, array $body): TestResponse
    {
        return $this->as($this->operator)->postJson('/api/v1/operations/orders/'.$order->id.'/courier-assignment', $body);
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
