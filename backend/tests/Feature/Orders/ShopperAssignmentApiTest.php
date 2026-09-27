<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\OrderShopperAssignment;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * The Shopper picker and the Shopper assignment, `docs/09` section 39,
 * `docs/04` section 11, `DL-37` (11), (14) and `DL-45`.
 */
final class ShopperAssignmentApiTest extends TestCase
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
        $shopper = $this->shopper();

        $admin = User::factory()->role(Role::Admin)->create();
        $this->as($admin)->getJson('/api/v1/operations/shoppers')->assertOk();
        $this->assign(Order::factory()->create(), $shopper, $admin)->assertOk();

        foreach ([Role::Customer, Role::Shopper, Role::Courier, Role::Manager] as $role) {
            $user = User::factory()->role($role)->create();
            $order = Order::factory()->create();
            $this->as($user)->getJson('/api/v1/operations/shoppers')->assertStatus(403);
            $this->assign($order, $shopper, $user)->assertStatus(403);
            $this->assign($order, $shopper, $user, 'put')->assertStatus(403);
        }
    }

    public function test_the_picker_lists_active_shoppers_by_name_with_the_orders_in_their_hands(): void
    {
        // Byte order would put the capital B first; the name order ignores case.
        $bobur = $this->shopper('Bobur Aliyev');
        $aziz = $this->shopper('aziz Karimov');
        $this->shopper('Blocked Shopper', blocked: true);
        User::factory()->role(Role::Courier)->create(['full_name' => 'A Courier']);
        OrderShopperAssignment::factory()->create(['shopper_id' => $bobur->id]);
        OrderShopperAssignment::factory()->create(['shopper_id' => $bobur->id]);
        OrderShopperAssignment::factory()->ended(AssignmentEndReason::Reassigned)->create(['shopper_id' => $aziz->id]);

        $response = $this->as($this->operator)->getJson('/api/v1/operations/shoppers')->assertOk();

        $this->assertSame([$aziz->id, $bobur->id], array_column($response->json('data'), 'id'));
        $this->assertSame(
            ['id' => $aziz->id, 'full_name' => 'aziz Karimov', 'phone' => $aziz->phone, 'current_assignment_count' => 0],
            $response->json('data.0')
        );
        $this->assertSame(2, $response->json('data.1.current_assignment_count'));
        $this->assertSame(2, $response->json('meta.pagination.total'));
    }

    public function test_an_assignment_moves_a_new_order_to_shopping_assigned_with_one_history_row(): void
    {
        $order = Order::factory()->create();
        $shopper = $this->shopper();

        $data = $this->assign($order, $shopper)->assertOk()->json('data');

        $this->assertSame('shopping_assigned', $data['status']);
        $this->assertCount(1, $data['shopper_assignments']);
        $assignment = $data['shopper_assignments'][0];
        $this->assertSame($shopper->id, $assignment['shopper']['id']);
        $this->assertSame(['id' => $this->operator->id, 'full_name' => 'Olim Operator'], $assignment['assigned_by']);
        $this->assertFalse($assignment['is_self_order']);
        $this->assertNull($assignment['ended_at']);

        $this->assertCount(1, $data['history']);
        $history = $data['history'][0];
        $this->assertSame('shopper_assigned', $history['event_type']);
        $this->assertSame('new', $history['from_status']);
        $this->assertSame('shopping_assigned', $history['to_status']);
        $this->assertSame($this->operator->id, $history['actor']['id']);
        $this->assertEquals(
            ['assignment_id' => $assignment['id'], 'shopper_id' => $shopper->id, 'is_self_order' => false],
            $history['details']
        );
    }

    public function test_the_current_shopper_again_is_a_natural_repeat(): void
    {
        $order = Order::factory()->create();
        $shopper = $this->shopper();
        $this->assign($order, $shopper)->assertOk();

        $this->assign($order, $shopper)->assertOk()->assertJsonPath('data.status', 'shopping_assigned');
        $this->assign($order, $shopper, method: 'put')->assertOk();
        // The id in capitals is the same Shopper.
        $this->as($this->operator)
            ->postJson('/api/v1/operations/orders/'.$order->id.'/shopper-assignment', ['shopper_id' => strtoupper($shopper->id)])
            ->assertOk();

        $this->assertSame(1, OrderShopperAssignment::query()->where('order_id', $order->id)->count());
        $this->assertSame(1, OrderHistory::query()->where('order_id', $order->id)->count());
    }

    public function test_a_reassignment_before_shopping_starts_ends_the_current_assignment(): void
    {
        $order = Order::factory()->create();
        $first = OrderShopperAssignment::factory()->accepted()->create(['order_id' => $order->id]);
        $order->forceFill(['status' => 'shopping_assigned'])->save();
        $second = $this->shopper();

        $data = $this->assign($order, $second, method: 'put')->assertOk()->json('data');

        $this->assertSame('shopping_assigned', $data['status']);
        $this->assertSame([$first->id, $data['shopper_assignments'][1]['id']], array_column($data['shopper_assignments'], 'id'));
        $this->assertSame('reassigned', $data['shopper_assignments'][0]['ended_reason']);
        $this->assertNotNull($data['shopper_assignments'][0]['ended_at']);
        $this->assertSame($second->id, $data['shopper_assignments'][1]['shopper']['id']);
        $this->assertNull($data['shopper_assignments'][1]['ended_at']);

        $history = $data['history'][0];
        $this->assertSame('shopper_reassigned', $history['event_type']);
        $this->assertNull($history['from_status']);
        $this->assertNull($history['to_status']);
        $this->assertEquals([
            'assignment_id' => $data['shopper_assignments'][1]['id'],
            'shopper_id' => $second->id,
            'is_self_order' => false,
            'previous_assignment_id' => $first->id,
            'previous_shopper_id' => $first->shopper_id,
        ], $history['details']);
    }

    public function test_the_shopper_must_be_an_active_shoppers_account(): void
    {
        $order = Order::factory()->create();

        foreach ([
            User::factory()->role(Role::Courier)->create(),
            User::factory()->role(Role::Operator)->create(),
            User::factory()->customer()->create(),
        ] as $notAShopper) {
            $this->assign($order, $notAShopper)->assertStatus(422)->assertJsonPath('code', 'validation_failed')
                ->assertJsonValidationErrors(['shopper_id']);
        }
        $this->postBody($order, ['shopper_id' => (string) Str::uuid()])->assertStatus(422)->assertJsonValidationErrors(['shopper_id']);
        $this->postBody($order, ['shopper_id' => 'not-a-uuid'])->assertStatus(422)->assertJsonValidationErrors(['shopper_id']);
        $this->postBody($order, [])->assertStatus(422)->assertJsonValidationErrors(['shopper_id']);
        $this->postBody($order, ['shopper_id' => $this->shopper()->id, 'is_self_order' => true])->assertStatus(422);

        $this->assign($order, $this->shopper(blocked: true))->assertStatus(409)->assertJsonPath('code', 'staff_not_active');

        $this->assertNothingWritten($order);
    }

    public function test_a_blocked_shopper_is_refused_before_the_repeat_and_the_order_state(): void
    {
        $order = Order::factory()->create();
        $shopper = $this->shopper();
        $this->assign($order, $shopper)->assertOk();
        $shopper->forceFill(['status' => 'blocked', 'blocked_at' => now()])->save();

        // A Shopper blocked since is not a repeat: the Operator must reassign.
        $this->assign($order, $shopper)->assertStatus(409)->assertJsonPath('code', 'staff_not_active');
        $this->assign($order, $shopper, method: 'put')->assertStatus(409)->assertJsonPath('code', 'staff_not_active');
        $this->assertSame(1, OrderShopperAssignment::query()->where('order_id', $order->id)->count());
        $this->assertSame(1, OrderHistory::query()->where('order_id', $order->id)->count());

        // Nor is the order's state asked first.
        $this->assign(Order::factory()->shoppingAssigned()->create(), $shopper)->assertStatus(409)->assertJsonPath('code', 'staff_not_active');
        $this->assign(Order::factory()->cancelled()->create(), $shopper)->assertStatus(409)->assertJsonPath('code', 'staff_not_active');
    }

    public function test_a_stale_or_retried_reassignment_never_undoes_a_newer_one(): void
    {
        $order = Order::factory()->create();
        [$a, $b, $c] = [$this->shopper('A'), $this->shopper('B'), $this->shopper('C')];
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

        $this->assertSame($c->id, $this->currentAssignmentOf($order)?->shopper_id);
        $this->assertSame(3, OrderShopperAssignment::query()->where('order_id', $order->id)->count());
        $this->assertSame(3, OrderHistory::query()->where('order_id', $order->id)->count());
    }

    public function test_a_reassignment_names_the_assignment_it_replaces_and_an_assignment_does_not(): void
    {
        $order = Order::factory()->shoppingAssigned()->create();
        $shopper = $this->shopper();
        $url = '/api/v1/operations/orders/'.$order->id.'/shopper-assignment';

        $this->as($this->operator)->putJson($url, ['shopper_id' => $shopper->id])
            ->assertStatus(422)->assertJsonValidationErrors(['replaces_assignment_id']);
        $this->as($this->operator)->putJson($url, ['shopper_id' => $shopper->id, 'replaces_assignment_id' => 'nope'])
            ->assertStatus(422)->assertJsonValidationErrors(['replaces_assignment_id']);
        $this->postBody(Order::factory()->create(), ['shopper_id' => $shopper->id, 'replaces_assignment_id' => (string) Str::uuid()])
            ->assertStatus(422);
        // The id in capitals is the same assignment.
        $this->as($this->operator)->putJson($url, [
            'shopper_id' => $shopper->id,
            'replaces_assignment_id' => strtoupper((string) $this->currentAssignmentOf($order)?->id),
        ])->assertOk();
    }

    public function test_an_order_in_another_state_is_a_conflict(): void
    {
        $shopper = $this->shopper();
        $assigned = Order::factory()->shoppingAssigned()->create();
        $new = Order::factory()->create();
        $shopping = Order::factory()->shopping()->create();
        $cancelled = Order::factory()->cancelled()->create();

        $this->assign($assigned, $shopper)->assertStatus(409)->assertJsonPath('code', 'order_state_conflict');
        $this->assign($new, $shopper, method: 'put')->assertStatus(409)->assertJsonPath('code', 'order_state_conflict');
        $this->assign($shopping, $shopper, method: 'put')->assertStatus(409)->assertJsonPath('code', 'order_state_conflict');
        $this->assign($shopping, $shopper)->assertStatus(409)->assertJsonPath('code', 'order_state_conflict');
        $this->assign($cancelled, $shopper)->assertStatus(409)->assertJsonPath('code', 'order_state_conflict');
        $this->assign($cancelled, $shopper, method: 'put')->assertStatus(409)->assertJsonPath('code', 'order_state_conflict');

        $this->as($this->operator)
            ->postJson('/api/v1/operations/orders/'.(string) Str::uuid().'/shopper-assignment', ['shopper_id' => $shopper->id])
            ->assertStatus(404);

        $this->assertSame(0, OrderHistory::query()->count());
        $this->assertSame(0, OrderShopperAssignment::query()->where('shopper_id', $shopper->id)->count());
        $this->assertSame('new', $new->fresh()?->status->value);
    }

    public function test_a_shopper_with_the_customers_phone_is_a_self_order_until_replaced(): void
    {
        $customer = User::factory()->customer()->create(['phone' => '+998901234567']);
        $order = Order::factory()->create(['customer_id' => $customer->id]);
        $self = User::factory()->role(Role::Shopper)->create(['phone' => '+998901234567']);

        $data = $this->assign($order, $self)->assertOk()->json('data');

        $this->assertTrue($data['shopper_assignments'][0]['is_self_order']);
        $this->assertTrue($data['history'][0]['details']['is_self_order']);
        $this->as($this->operator)->getJson('/api/v1/operations/orders')->assertJsonPath('data.0.is_self_order', true);
        $this->as($this->operator)->getJson('/api/v1/operations/attention')->assertJsonPath('data.0.order_id', $order->id);

        $data = $this->assign($order, $this->shopper(), method: 'put')->assertOk()->json('data');

        $this->assertFalse($data['shopper_assignments'][1]['is_self_order']);
        $this->as($this->operator)->getJson('/api/v1/operations/orders')->assertJsonPath('data.0.is_self_order', false);
        $this->assertSame([], $this->as($this->operator)->getJson('/api/v1/operations/attention')->json('data'));
    }

    private function assertNothingWritten(Order $order): void
    {
        $this->assertSame('new', $order->fresh()?->status->value);
        $this->assertSame(0, OrderShopperAssignment::query()->where('order_id', $order->id)->count());
        $this->assertSame(0, OrderHistory::query()->where('order_id', $order->id)->count());
    }

    private function shopper(string $name = 'Sardor Shopper', bool $blocked = false): User
    {
        $factory = User::factory()->role(Role::Shopper);

        return ($blocked ? $factory->blocked() : $factory)->create(['full_name' => $name]);
    }

    /**
     * A `PUT` replaces [$replaces], by default the order's current assignment
     * as the Operator would have seen it.
     */
    private function assign(Order $order, User $shopper, ?User $as = null, string $method = 'post', ?string $replaces = null): TestResponse
    {
        $body = ['shopper_id' => $shopper->id];
        if ($method === 'put') {
            $body['replaces_assignment_id'] = $replaces
                ?? $this->currentAssignmentOf($order)->id
                ?? (string) Str::uuid();
        }

        return $this->as($as ?? $this->operator)->json(
            strtoupper($method),
            '/api/v1/operations/orders/'.$order->id.'/shopper-assignment',
            $body,
        );
    }

    private function currentAssignmentOf(Order $order): ?OrderShopperAssignment
    {
        return OrderShopperAssignment::query()->where('order_id', $order->id)->whereNull('ended_at')->first();
    }

    /**
     * @param  array<string, mixed>  $body
     */
    private function postBody(Order $order, array $body): TestResponse
    {
        return $this->as($this->operator)->postJson('/api/v1/operations/orders/'.$order->id.'/shopper-assignment', $body);
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
