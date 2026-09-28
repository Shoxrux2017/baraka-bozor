<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\CustomerApproval;
use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\ItemRemovedReason;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\Role;
use App\Models\Enums\SubstitutionResolution;
use App\Models\Enums\UnitCode;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\OrderItem;
use App\Models\OrderShopperAssignment;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * The Shopper's assigned orders, accept and start: `docs/09` sections 28 and
 * 29, `docs/04` section 12, `DL-54` (3), (5), (6), (23) and `DL-56`.
 */
final class ShopperOrdersApiTest extends TestCase
{
    use RefreshDatabase;

    private User $shopper;

    protected function setUp(): void
    {
        parent::setUp();

        $this->shopper = User::factory()->role(Role::Shopper)->create();
    }

    public function test_only_a_shopper_reaches_the_shopper_orders(): void
    {
        $order = $this->assigned();

        $this->getJson('/api/v1/shopper/orders')->assertStatus(401);

        foreach ([Role::Customer, Role::Courier, Role::Operator, Role::Admin, Role::Manager] as $role) {
            $user = User::factory()->role($role)->create();
            $this->as($user)->getJson('/api/v1/shopper/orders')->assertStatus(403);
            $this->as($user)->getJson("/api/v1/shopper/orders/{$order->id}")->assertStatus(403);
            $this->as($user)->postJson("/api/v1/shopper/orders/{$order->id}/accept")->assertStatus(403);
            $this->as($user)->postJson("/api/v1/shopper/orders/{$order->id}/start")->assertStatus(403);
        }
    }

    public function test_the_list_holds_the_shoppers_current_orders_the_longest_waiting_first(): void
    {
        $later = $this->assigned(at: now()->subMinutes(5));
        $earlier = $this->assigned(at: now()->subMinutes(30));
        OrderItem::factory()->for($earlier)->count(2)->create();
        OrderItem::factory()->for($earlier)->removed(ItemRemovedReason::CustomerRemoved)->create();
        OrderItem::factory()->for($earlier)->purchased()->create();

        // Not the Shopper's now: replaced, shopped, or someone else's.
        OrderShopperAssignment::factory()->ended(AssignmentEndReason::Reassigned)->create(['shopper_id' => $this->shopper->id]);
        Order::factory()->readyForDelivery()->create();
        $this->assigned(shopper: User::factory()->role(Role::Shopper)->create());

        $response = $this->as($this->shopper)->getJson('/api/v1/shopper/orders')->assertOk();

        $this->assertSame([$earlier->id, $later->id], array_column($response->json('data'), 'id'));
        $this->assertSame(2, $response->json('meta.pagination.total'));
        $row = $response->json('data.0');
        $this->assertSame([
            'id', 'order_number', 'status', 'item_count', 'open_item_count', 'delivery_time_note', 'assignment',
        ], array_keys($row));
        $this->assertSame('shopping_assigned', $row['status']);
        $this->assertSame(3, $row['item_count'], 'The line the Customer took out is not the Shopper\'s.');
        $this->assertSame(2, $row['open_item_count']);
        $this->assertNull($row['assignment']['accepted_at']);
    }

    public function test_an_order_shows_what_to_buy_and_the_bound_of_each_product_never_the_address(): void
    {
        $order = $this->shopping();
        $estimate = OrderItem::factory()->for($order)->create(['customer_note_snapshot' => 'Спелые']);
        $fixed = OrderItem::factory()->for($order)->for(Product::factory()->fixed()->unit(UnitCode::Piece)->state(['market_price_uzs' => 3000]))
            ->create(['ordered_quantity' => '3']);
        $replacement = Product::factory()->unit(UnitCode::Piece)->create(['market_price_uzs' => 2800]);
        $fixed->forceFill([
            'fulfilled_product_id' => $replacement->id,
            'fulfilled_product_name_uz_snapshot' => $replacement->name_uz,
            'fulfilled_product_name_ru_snapshot' => $replacement->name_ru,
            'fulfilled_unit_code_snapshot' => UnitCode::Piece,
            'substitution_resolution' => SubstitutionResolution::Automatic,
        ])->save();
        $raised = OrderItem::factory()->for($order)->create(['approved_unit_price_ceiling_uzs' => 23000]);
        OrderItem::factory()->for($order)->removed(ItemRemovedReason::CustomerRemoved)->create();
        $bought = OrderItem::factory()->for($order)->purchased()->create();
        $asked = CustomerApproval::factory()->create([
            'order_item_id' => OrderItem::factory()->for($order)->awaitingCustomer(),
        ]);

        $data = $this->as($this->shopper)->getJson("/api/v1/shopper/orders/{$order->id}")->assertOk()->json('data');

        $this->assertSame([
            'id', 'order_number', 'status', 'delivery_time_note', 'customer_phone', 'assignment', 'can_accept', 'can_start', 'items',
        ], array_keys($data));
        $this->assertSame($order->recipient_phone_snapshot, $data['customer_phone']);
        $this->assertFalse($data['can_accept']);
        $this->assertFalse($data['can_start']);
        $this->assertSame([$estimate->id, $fixed->id, $raised->id, $bought->id, $asked->order_item_id], array_column($data['items'], 'id'));

        $line = $data['items'][0];
        $this->assertSame('2.000', $line['quantity']);
        $this->assertSame('Спелые', $line['customer_note']);
        $this->assertSame(16000, $line['market_price_uzs']);
        $this->assertSame(18400, $line['customer_unit_price_uzs']);
        // 18 400 plus the 15 % tolerance is 21 160; under the 15 % markup the
        // stall may charge up to 18 400.
        $this->assertSame(['customer_unit_price_uzs' => 21160, 'market_price_uzs' => 18400], $line['bound']);
        $this->assertNull($line['replacement']);
        $this->assertNull($line['purchase']);
        $this->assertNull($line['pending_approval']);

        $line = $data['items'][1];
        $this->assertNull($line['bound'], 'A fixed line bought as itself has no bound (BR-PRICE-002).');
        $this->assertSame([
            'product_id' => $replacement->id,
            'name_uz' => $replacement->name_uz,
            'name_ru' => $replacement->name_ru,
            'market_price_uzs' => 2800,
            'substitution_resolution' => 'automatic',
            // BR-PRICE-005: the replacement of a fixed line stays within its 3 450.
            'bound' => ['customer_unit_price_uzs' => 3450, 'market_price_uzs' => 3000],
        ], $line['replacement']);

        $this->assertSame(23000, $data['items'][2]['bound']['customer_unit_price_uzs'], 'BR-APP-008: the approved ceiling.');
        $this->assertSame(20000, $data['items'][2]['bound']['market_price_uzs']);

        $this->assertSame([
            'product_id' => $bought->product_id,
            'purchased_quantity' => '2.000',
            'billable_quantity' => '2.000',
            'actual_market_price_uzs' => 16000,
            'billable_unit_price_uzs' => 18400,
            'line_total_uzs' => 36800,
        ], $data['items'][3]['purchase']);

        $this->assertSame(
            ['id' => $asked->id, 'type' => 'price_over_tolerance', 'expires_at' => $asked->expires_at->toIso8601ZuluString()],
            $data['items'][4]['pending_approval']
        );

        $json = json_encode($data, JSON_THROW_ON_ERROR);
        foreach ([$order->street_snapshot, $order->recipient_name_snapshot, '"address"', 'latitude', '"totals"', 'payment'] as $hidden) {
            $this->assertStringNotContainsString($hidden, $json, "docs/02 section 11: the Shopper never sees {$hidden}.");
        }
    }

    public function test_the_customers_phone_shows_only_while_the_order_is_shopped(): void
    {
        $order = $this->assigned();

        $this->assertNull($this->as($this->shopper)->getJson("/api/v1/shopper/orders/{$order->id}")->json('data.customer_phone'));
    }

    public function test_an_order_the_shopper_does_not_hold_now_is_not_found(): void
    {
        $someoneElses = $this->assigned(shopper: User::factory()->role(Role::Shopper)->create());
        $replaced = OrderShopperAssignment::factory()->ended(AssignmentEndReason::Reassigned)->create(['shopper_id' => $this->shopper->id]);
        $shopped = Order::factory()->readyForDelivery()->create();
        $shopped->shopperAssignments()->update(['shopper_id' => $this->shopper->id]);

        foreach ([$someoneElses->id, $replaced->order_id, $shopped->id, (string) Str::uuid(), 'not-a-uuid'] as $id) {
            $this->as($this->shopper)->getJson("/api/v1/shopper/orders/{$id}")->assertStatus(404)->assertJsonPath('code', 'resource_not_found');
            $this->as($this->shopper)->postJson("/api/v1/shopper/orders/{$id}/accept")->assertStatus(404);
            $this->as($this->shopper)->postJson("/api/v1/shopper/orders/{$id}/start")->assertStatus(404);
        }

        $this->assertSame(0, OrderHistory::query()->count());
    }

    public function test_accepting_records_it_once(): void
    {
        $order = $this->assigned();

        $data = $this->accept($order)->assertOk()->json('data');
        $this->assertNotNull($data['assignment']['accepted_at']);
        $this->assertFalse($data['can_accept']);
        $this->assertTrue($data['can_start']);
        $this->assertSame('shopping_assigned', $data['status']);

        $this->accept($order)->assertOk();

        $history = OrderHistory::query()->where('order_id', $order->id)->sole();
        $this->assertSame(OrderHistoryEvent::ShopperAccepted, $history->event_type);
        $this->assertSame($this->shopper->id, $history->actor_user_id);
        $this->assertNull($history->to_status);
        $this->assertSame(['assignment_id' => $order->currentShopperAssignment?->id], $history->details);
    }

    public function test_a_start_needs_the_acceptance_and_then_closes_the_customers_editing(): void
    {
        $order = $this->assigned();

        $this->start($order)->assertStatus(409)->assertJsonPath('code', 'order_state_conflict');
        $this->assertSame(OrderStatus::ShoppingAssigned, $order->fresh()?->status);

        $this->accept($order)->assertOk();
        $data = $this->start($order)->assertOk()->json('data');
        $this->assertSame('shopping', $data['status']);
        $this->assertNotNull($data['assignment']['started_at']);
        $this->assertSame($order->recipient_phone_snapshot, $data['customer_phone']);
        $this->assertFalse($data['can_start']);

        $this->start($order)->assertOk();

        $started = OrderHistory::query()->where('order_id', $order->id)->where('event_type', OrderHistoryEvent::StatusChanged)->sole();
        $this->assertSame(OrderStatus::ShoppingAssigned, $started->from_status);
        $this->assertSame(OrderStatus::Shopping, $started->to_status);
        $this->assertSame($this->shopper->id, $started->actor_user_id);
        $this->assertNotNull($order->fresh()->shopping_started_at);

        $customer = $order->customer;
        $customerSession = $this->withToken($customer->createToken('c')->plainTextToken);
        $customerSession->getJson("/api/v1/customer/orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('data.can_edit', false)
            ->assertJsonPath('data.can_cancel_directly', false);
        $customerSession->withHeader('Idempotency-Key', (string) Str::uuid())
            ->postJson("/api/v1/customer/orders/{$order->id}/cancel")
            ->assertStatus(409);
    }

    public function test_accept_and_start_take_no_body(): void
    {
        $order = $this->assigned();

        $this->as($this->shopper)->postJson("/api/v1/shopper/orders/{$order->id}/accept", ['accepted' => true])
            ->assertStatus(422)->assertJsonPath('code', 'validation_failed');
        $this->as($this->shopper)->postJson("/api/v1/shopper/orders/{$order->id}/start", ['note' => 'go'])
            ->assertStatus(422);
        $this->assertNull($order->currentShopperAssignment?->fresh()?->accepted_at);
    }

    private function assigned(?User $shopper = null, mixed $at = null): Order
    {
        $order = Order::factory()->state(['status' => OrderStatus::ShoppingAssigned])->create();
        OrderShopperAssignment::factory()->create([
            'order_id' => $order->id,
            'shopper_id' => ($shopper ?? $this->shopper)->id,
            'assigned_at' => $at ?? now(),
        ]);

        return $order;
    }

    private function shopping(): Order
    {
        $order = Order::factory()->shopping()->create();
        $order->shopperAssignments()->update(['shopper_id' => $this->shopper->id]);

        return $order;
    }

    private function accept(Order $order): TestResponse
    {
        return $this->as($this->shopper)->postJson("/api/v1/shopper/orders/{$order->id}/accept");
    }

    private function start(Order $order): TestResponse
    {
        return $this->as($this->shopper)->postJson("/api/v1/shopper/orders/{$order->id}/start");
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
