<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\BusinessSettings;
use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\ItemRemovedReason;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\Role;
use App\Models\Enums\UnitCode;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * Editing an order and cancelling it before shopping starts, `docs/09`
 * sections 21 and 22, `BR-ORDER-004`, `BR-CAN-001`, `DL-6`, `DL-37` (8), (9),
 * (13). Orders are placed at a 15 % markup, with a minimum of 50 000.
 */
final class EditAndCancelOrderApiTest extends TestCase
{
    use RefreshDatabase;

    private User $customer;

    private Product $tomatoes;

    private Product $bread;

    private Order $order;

    private OrderItem $tomatoLine;

    private OrderItem $breadLine;

    protected function setUp(): void
    {
        parent::setUp();

        DB::table('business_settings')->where('id', BusinessSettings::SINGLETON_ID)->update([
            'markup_percent' => '15.00',
            'minimum_order_uzs' => 50000,
        ]);

        $this->customer = User::factory()->customer()->create();
        $this->tomatoes = Product::factory()->create(['market_price_uzs' => 16000]);
        $this->bread = Product::factory()->fixed()->unit(UnitCode::Piece)->create(['market_price_uzs' => 3000]);
        $this->order = Order::factory()->create(['customer_id' => $this->customer->id, 'delivery_time_note' => 'Ertalab']);
        $this->tomatoLine = OrderItem::factory()->for($this->order)->for($this->tomatoes)->create(['ordered_quantity' => '3.000']);
        $this->breadLine = OrderItem::factory()->for($this->order)->for($this->bread)->create(['ordered_quantity' => '2.000']);
    }

    public function test_a_line_that_stays_keeps_its_price_while_the_catalog_moved(): void
    {
        Product::query()->whereKey($this->tomatoes->id)->update(['market_price_uzs' => 20000]);

        $data = $this->edit([
            ['product_id' => $this->tomatoes->id, 'quantity' => '4', 'customer_note' => 'Qizil', 'substitution_policy' => 'contact_before_substitution'],
            ['product_id' => $this->bread->id, 'quantity' => '2'],
        ])->assertOk()->json('data');

        $tomato = $this->tomatoLine->fresh();
        $this->assertNotNull($tomato);
        $this->assertSame(18400, $tomato->customer_unit_price_uzs_snapshot, 'DL-6: a line that stays keeps its price.');
        $this->assertSame('4.000', $tomato->ordered_quantity);
        $this->assertSame('Qizil', $tomato->customer_note_snapshot);
        $this->assertSame(80500, $data['totals']['merchandise_subtotal_uzs'], '18 400 × 4 + 3 450 × 2.');

        $details = OrderHistory::query()->where('event_type', OrderHistoryEvent::Edited->value)->sole()->details;
        $this->assertNotNull($details);
        $this->assertSame([], $details['added']);
        $this->assertSame([], $details['removed']);
        $this->assertCount(1, $details['changed']);
        $this->assertSame(
            ['quantity' => '3.000', 'customer_note' => null, 'substitution_policy' => 'allow_similar_substitution'],
            $details['changed'][0]['before']
        );
        $this->assertSame('4.000', $details['changed'][0]['after']['quantity']);
    }

    public function test_an_added_line_takes_the_current_price_and_markup_and_the_order_keeps_its_own(): void
    {
        DB::table('business_settings')->update(['markup_percent' => '20.00']);
        $cheese = Product::factory()->create(['market_price_uzs' => 50000]);

        $this->edit([
            ['product_id' => $this->tomatoes->id, 'quantity' => '3'],
            ['product_id' => $this->bread->id, 'quantity' => '2'],
            ['product_id' => $cheese->id, 'quantity' => '0.5'],
        ])->assertOk();

        $added = OrderItem::query()->where('order_id', $this->order->id)->where('product_id', $cheese->id)->sole();
        $this->assertSame(60000, $added->customer_unit_price_uzs_snapshot);
        $this->assertSame('20.00', $added->markup_percent_snapshot, 'DL-37 (8): the markup its price was made with.');
        $this->assertSame('15.00', $this->order->fresh()?->markup_percent_snapshot, 'The order keeps its own (DL-6).');
    }

    public function test_a_line_left_out_is_removed_not_deleted_and_adding_it_back_prices_it_anew(): void
    {
        $this->edit([['product_id' => $this->tomatoes->id, 'quantity' => '3']])
            ->assertOk()
            ->assertJsonPath('data.totals.merchandise_subtotal_uzs', 55200);

        $removed = $this->breadLine->fresh();
        $this->assertNotNull($removed);
        $this->assertSame(OrderItemStatus::Removed, $removed->status);
        $this->assertSame(ItemRemovedReason::CustomerRemoved, $removed->removed_reason_code);

        Product::query()->whereKey($this->bread->id)->update(['market_price_uzs' => 4000]);
        $this->edit([
            ['product_id' => $this->tomatoes->id, 'quantity' => '3'],
            ['product_id' => $this->bread->id, 'quantity' => '2'],
        ])->assertOk();

        $again = OrderItem::query()->where('order_id', $this->order->id)->where('product_id', $this->bread->id)
            ->where('status', OrderItemStatus::Pending->value)->sole();
        $this->assertNotSame($this->breadLine->id, $again->id);
        $this->assertSame(4600, $again->customer_unit_price_uzs_snapshot);
        $this->assertSame(3, OrderItem::query()->where('order_id', $this->order->id)->count());
    }

    public function test_an_edit_that_changes_nothing_writes_no_history(): void
    {
        $this->edit([
            ['product_id' => $this->tomatoes->id, 'quantity' => '3.000'],
            ['product_id' => $this->bread->id, 'quantity' => '2'],
        ], 'Ertalab')->assertOk();

        $this->assertSame(0, OrderHistory::query()->count());
    }

    public function test_the_delivery_wish_is_part_of_the_edit(): void
    {
        $this->edit([
            ['product_id' => $this->tomatoes->id, 'quantity' => '3'],
            ['product_id' => $this->bread->id, 'quantity' => '2'],
        ], 'Kechqurun')->assertOk()->assertJsonPath('data.delivery_time_note', 'Kechqurun');

        // jsonb keeps an object's keys in its own order: compare the pairs.
        $this->assertEquals(
            ['before' => 'Ertalab', 'after' => 'Kechqurun'],
            OrderHistory::query()->sole()->details['delivery_time_note'] ?? null
        );
    }

    public function test_the_list_is_held_to_its_shape(): void
    {
        $line = ['product_id' => $this->tomatoes->id, 'quantity' => '3'];

        $this->edit([])->assertStatus(422)->assertJsonStructure(['errors' => ['items']]);
        $this->edit([$line, $line])->assertStatus(422)->assertJsonStructure(['errors' => ['items.1.product_id']]);
        $this->edit([$line, ['product_id' => strtoupper($this->tomatoes->id), 'quantity' => '1']])->assertStatus(422);
        $this->edit(array_map(static fn (int $n): array => ['product_id' => (string) Str::uuid(), 'quantity' => '1'], range(1, 101)))
            ->assertStatus(422)->assertJsonStructure(['errors' => ['items']]);
        $this->edit([$line + ['customer_unit_price_uzs' => 1]])->assertStatus(422);
        $this->asCustomer()->putJson($this->url(), ['items' => [$line]])->assertStatus(422)->assertJsonStructure(['errors' => ['delivery_time_note']]);
        $this->edit([['product_id' => $this->bread->id, 'quantity' => '2.5'], $line])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['items.0.quantity']]);
    }

    public function test_an_added_product_the_customer_may_not_see_is_named(): void
    {
        $hidden = Product::factory()->archived()->create();

        $this->edit([
            ['product_id' => $this->tomatoes->id, 'quantity' => '3'],
            ['product_id' => $hidden->id, 'quantity' => '1'],
        ])->assertStatus(409)->assertJsonPath('code', 'product_unavailable')->assertJsonPath('details.product_ids', [$hidden->id]);
    }

    public function test_the_minimum_is_checked_again_and_nothing_is_written_when_it_fails(): void
    {
        $this->edit([['product_id' => $this->bread->id, 'quantity' => '2']])
            ->assertStatus(409)
            ->assertJsonPath('code', 'minimum_order_not_reached')
            ->assertJsonPath('details.shortfall_uzs', 43100);

        $this->assertSame(OrderItemStatus::Pending, $this->tomatoLine->fresh()?->status);
        $this->assertSame(0, OrderHistory::query()->count());
    }

    public function test_a_minimum_raised_after_the_order_reaches_it_only_through_an_edit_that_lowers_it(): void
    {
        DB::table('business_settings')->update(['minimum_order_uzs' => 100000]);
        $both = [['product_id' => $this->tomatoes->id, 'quantity' => '3'], ['product_id' => $this->bread->id, 'quantity' => '2']];

        $this->edit($both, 'Ertalab')->assertOk();
        $this->assertSame(0, OrderHistory::query()->count(), 'An unchanged list is a natural repeat.');
        $this->edit($both, 'Kechqurun')->assertOk();
        $this->edit([['product_id' => $this->tomatoes->id, 'quantity' => '4'], ['product_id' => $this->bread->id, 'quantity' => '2']], 'Kechqurun')
            ->assertOk();

        $this->edit([['product_id' => $this->tomatoes->id, 'quantity' => '4']], 'Kechqurun')
            ->assertStatus(409)
            ->assertJsonPath('code', 'minimum_order_not_reached')
            ->assertJsonPath('details.shortfall_uzs', 26400);
    }

    public function test_the_markup_and_fees_moving_never_reach_a_line_that_stays_or_the_order(): void
    {
        DB::table('business_settings')->update(['markup_percent' => '40.00', 'delivery_fee_uzs' => 99000, 'service_fee_fixed_uzs' => 9900]);

        $this->edit([['product_id' => $this->tomatoes->id, 'quantity' => '5'], ['product_id' => $this->bread->id, 'quantity' => '2']])->assertOk();

        $kept = $this->tomatoLine->fresh();
        $order = $this->order->fresh();
        $this->assertNotNull($kept);
        $this->assertNotNull($order);
        $this->assertSame(18400, $kept->customer_unit_price_uzs_snapshot);
        $this->assertSame('15.00', $kept->markup_percent_snapshot);
        $this->assertSame(15000, $order->delivery_fee_uzs_snapshot);
        $this->assertSame(5000, $order->service_fee_fixed_uzs_snapshot);
    }

    public function test_a_line_that_stays_is_kept_although_its_product_changed_unit_or_was_hidden(): void
    {
        Product::query()->whereKey($this->tomatoes->id)->update(['unit_code' => 'piece', 'is_active' => false]);

        $this->edit([
            ['product_id' => strtoupper($this->tomatoes->id), 'quantity' => '3.5'],
            ['product_id' => $this->bread->id, 'quantity' => '2'],
        ])->assertOk();

        $this->assertSame('3.500', $this->tomatoLine->fresh()?->ordered_quantity, 'Held to the unit it was ordered in.');
    }

    public function test_an_order_is_edited_only_before_shopping_starts(): void
    {
        $line = [['product_id' => $this->tomatoes->id, 'quantity' => '3']];

        $assigned = Order::factory()->shoppingAssigned()->create(['customer_id' => $this->customer->id]);
        OrderItem::factory()->for($assigned)->for($this->tomatoes)->create(['ordered_quantity' => '3.000']);
        $this->edit($line, null, $assigned)->assertOk();

        $assigned->currentShopperAssignment?->forceFill(['accepted_at' => now(), 'started_at' => now()])->save();
        foreach ([$assigned, Order::factory()->shopping()->create(['customer_id' => $this->customer->id]), Order::factory()->cancelled()->create(['customer_id' => $this->customer->id])] as $locked) {
            $this->edit($line, null, $locked)->assertStatus(409)->assertJsonPath('code', 'order_editing_locked');
        }
    }

    public function test_another_customers_order_is_not_found_and_staff_are_refused(): void
    {
        $line = [['product_id' => $this->tomatoes->id, 'quantity' => '3']];
        $other = User::factory()->customer()->create();

        $this->withToken($other->createToken('t')->plainTextToken)
            ->putJson($this->url(), ['items' => $line, 'delivery_time_note' => null])->assertStatus(404);
        $shopper = User::factory()->role(Role::Shopper)->create();
        $this->withToken($shopper->createToken('t')->plainTextToken)
            ->putJson($this->url(), ['items' => $line, 'delivery_time_note' => null])->assertStatus(403);
    }

    public function test_a_new_order_is_cancelled_at_once_and_owes_nothing(): void
    {
        $data = $this->cancel($this->order, ['reason' => 'Rejam o\'zgardi'])->assertOk()->json('data');

        $this->assertSame('cancelled', $data['status']);
        $this->assertSame('customer_cancelled', $data['cancellation_reason_code']);
        $this->assertSame('none', $data['totals']['total_kind']);
        $this->assertNull($data['totals']['total_uzs']);
        $this->assertFalse($data['can_cancel_directly']);
        $this->assertSame(['removed', 'removed'], array_column($data['items'], 'status'));
        $this->assertSame(['order_cancelled', 'order_cancelled'], array_column($data['items'], 'removed_reason_code'));

        $history = OrderHistory::query()->sole();
        $this->assertSame(OrderStatus::New, $history->from_status);
        $this->assertSame(OrderStatus::Cancelled, $history->to_status);
        $this->assertSame('Rejam o\'zgardi', $history->note);
    }

    public function test_cancelling_an_assigned_order_ends_the_shoppers_assignment(): void
    {
        $assigned = Order::factory()->shoppingAssigned()->create(['customer_id' => $this->customer->id]);
        $assignment = $assigned->currentShopperAssignment;
        $this->assertNotNull($assignment);

        $this->cancel($assigned)->assertOk()->assertJsonPath('data.status', 'cancelled');

        $this->assertSame(AssignmentEndReason::OrderCancelled, $assignment->fresh()?->ended_reason);
        $this->assertSame(OrderStatus::ShoppingAssigned, OrderHistory::query()->sole()->from_status);
    }

    public function test_a_cancelled_order_is_a_natural_repeat_and_a_retry_replays(): void
    {
        $key = (string) Str::uuid();
        $this->cancel($this->order, [], $key)->assertOk();
        $this->cancel($this->order, [], $key)->assertOk()->assertJsonPath('data.status', 'cancelled');
        $this->cancel($this->order)->assertOk()->assertJsonPath('data.status', 'cancelled');

        $this->assertSame(1, OrderHistory::query()->count());

        $another = Order::factory()->create(['customer_id' => $this->customer->id]);
        $this->cancel($another, [], $key)->assertStatus(409)->assertJsonPath('code', 'idempotency_key_reused');
    }

    public function test_an_order_in_shopping_or_later_is_not_cancelled_directly(): void
    {
        $started = Order::factory()->shoppingAssigned()->create(['customer_id' => $this->customer->id]);
        $started->currentShopperAssignment?->forceFill(['accepted_at' => now(), 'started_at' => now()])->save();
        $this->cancel($started)->assertStatus(409)->assertJsonPath('code', 'order_cancellation_not_allowed');

        foreach ([Order::factory()->shopping(), Order::factory()->readyForDelivery(), Order::factory()->completed()] as $factory) {
            $this->cancel($factory->create(['customer_id' => $this->customer->id]))
                ->assertStatus(409)->assertJsonPath('code', 'order_cancellation_not_allowed');
        }
    }

    public function test_a_cancellation_needs_its_key_and_the_customers_own_order(): void
    {
        $this->asCustomer()->postJson($this->url($this->order, 'cancel'))->assertStatus(400);
        $this->cancel($this->order, ['reason' => str_repeat('a', 301)])->assertStatus(422);
        $this->cancel(Order::factory()->create())->assertStatus(404);
        $this->assertSame(OrderStatus::New, $this->order->fresh()?->status);
    }

    /**
     * @param  list<array<string, mixed>>  $items
     */
    private function edit(array $items, ?string $note = null, ?Order $order = null): TestResponse
    {
        return $this->asCustomer()->putJson($this->url($order), ['items' => $items, 'delivery_time_note' => $note]);
    }

    /**
     * @param  array<string, mixed>  $body
     */
    private function cancel(Order $order, array $body = [], ?string $key = null): TestResponse
    {
        return $this->asCustomer()->postJson($this->url($order, 'cancel'), $body, ['Idempotency-Key' => $key ?? (string) Str::uuid()]);
    }

    private function url(?Order $order = null, string $action = 'items'): string
    {
        return '/api/v1/customer/orders/'.($order ?? $this->order)->id.'/'.$action;
    }

    private function asCustomer(): self
    {
        return $this->withToken($this->customer->createToken('t')->plainTextToken);
    }
}
