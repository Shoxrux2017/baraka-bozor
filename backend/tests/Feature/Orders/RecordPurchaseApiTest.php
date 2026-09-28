<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderItemStatus;
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
 * Recording a purchase: `docs/09` section 30, `docs/04` sections 13 to 15,
 * `DL-54` (4), (5), `DL-55` (12) and `DL-57`.
 *
 * The factory's lines: a kg estimate at 16 000 market, 18 400 to the
 * Customer under 15 %, ordered 2.000; the order's tolerance is 15 %, so the
 * estimate's ceiling is 21 160.
 */
final class RecordPurchaseApiTest extends TestCase
{
    use RefreshDatabase;

    private User $shopper;

    private Order $order;

    protected function setUp(): void
    {
        parent::setUp();

        $this->shopper = User::factory()->role(Role::Shopper)->create();
        $this->order = Order::factory()->shopping()->create();
        $this->order->shopperAssignments()->update(['shopper_id' => $this->shopper->id]);
    }

    public function test_a_fixed_line_bought_as_itself_is_billed_at_its_snapshot_whatever_was_paid(): void
    {
        $line = $this->fixedLine();

        $data = $this->purchase($line, ['purchased_quantity' => '3', 'actual_market_price_uzs' => 3900])->assertOk()->json('data');

        $bought = $line->fresh();
        $this->assertSame(OrderItemStatus::Purchased, $bought?->status);
        $this->assertSame(3450, $bought->billable_unit_price_uzs);
        $this->assertSame(3900, $bought->actual_market_price_uzs, 'The price paid is kept for the figures.');
        $this->assertSame(10350, $bought->line_total_uzs);
        $this->assertSame($line->product_id, $bought->fulfilled_product_id);
        $this->assertSame([
            'product_id' => $line->product_id,
            'purchased_quantity' => '3',
            'billable_quantity' => '3',
            'actual_market_price_uzs' => 3900,
            'billable_unit_price_uzs' => 3450,
            'line_total_uzs' => 10350,
        ], $data['items'][0]['purchase']);

        // A fixed line may be bought without saying what was paid.
        $other = $this->fixedLine();
        $this->purchase($other, ['purchased_quantity' => '3'])->assertOk();
        $this->assertNull($other->fresh()?->actual_market_price_uzs);

        $history = OrderHistory::query()->where('order_id', $this->order->id)->oldest('created_at')->oldest('id')->first();
        $this->assertSame(OrderHistoryEvent::ItemPurchased, $history?->event_type);
        $this->assertSame($this->shopper->id, $history->actor_user_id);
        $this->assertNull($history->to_status);
        $this->assertSame($line->id, $history?->details['item_id'] ?? null);
    }

    public function test_an_estimate_is_billed_from_the_price_paid_up_to_its_ceiling(): void
    {
        $within = $this->estimateLine();
        $this->purchase($within, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 17000])->assertOk();
        $this->assertSame(19550, $within->fresh()?->billable_unit_price_uzs, 'half_up(17 000 × 1.15)');
        $this->assertSame(39100, $within->fresh()->line_total_uzs);

        $atTheCeiling = $this->estimateLine();
        $this->purchase($atTheCeiling, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 18400])->assertOk();
        $this->assertSame(21160, $atTheCeiling->fresh()?->billable_unit_price_uzs);

        $above = $this->estimateLine();
        $key = (string) Str::uuid();
        $this->purchase($above, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 18401], $key)
            ->assertStatus(409)
            ->assertJsonPath('code', 'customer_approval_required')
            ->assertJsonPath('details', [
                'approval_type' => 'price_over_tolerance',
                'ceiling_customer_unit_price_uzs' => 21160,
                'proposed_customer_unit_price_uzs' => 21161,
            ]);
        $this->assertSame(OrderItemStatus::Pending, $above->fresh()?->status);

        // A refusal frees the key: the same key with a price within the
        // ceiling is judged again (DL-39 (2)).
        $this->purchase($above, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 18000], $key)->assertOk();
    }

    public function test_an_approved_ceiling_raises_the_originals_bound(): void
    {
        $line = $this->estimateLine(['approved_unit_price_ceiling_uzs' => 23000]);

        $this->purchase($line, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 20001])
            ->assertStatus(409)->assertJsonPath('details.ceiling_customer_unit_price_uzs', 23000);
        $this->purchase($line, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 20000])->assertOk();
        $this->assertSame(23000, $line->fresh()?->billable_unit_price_uzs);
    }

    public function test_the_excess_is_never_billed_and_a_shortfall_needs_the_customer(): void
    {
        $excess = $this->estimateLine(['ordered_quantity' => '5.000']);
        $this->purchase($excess, ['purchased_quantity' => '5.200', 'actual_market_price_uzs' => 16000])->assertOk();
        $this->assertSame('5.200', $excess->fresh()?->purchased_quantity);
        $this->assertSame('5.000', $excess->fresh()->billable_quantity, 'BR-QTY-004: 5.2 bought, 5 billed.');
        $this->assertSame(92000, $excess->fresh()->line_total_uzs);

        $short = $this->estimateLine(['ordered_quantity' => '5.000']);
        $this->purchase($short, ['purchased_quantity' => '4.990', 'actual_market_price_uzs' => 16000])
            ->assertStatus(409)
            ->assertJsonPath('code', 'customer_approval_required')
            ->assertJsonPath('details', ['approval_type' => 'reduced_quantity', 'required_quantity' => '5.000']);

        $capped = $this->estimateLine(['ordered_quantity' => '5.000', 'approved_quantity_cap' => '4.000']);
        $this->purchase($capped, ['purchased_quantity' => '3.999', 'actual_market_price_uzs' => 16000])
            ->assertStatus(409)->assertJsonPath('details.required_quantity', '4.000');
        $this->purchase($capped, ['purchased_quantity' => '4.100', 'actual_market_price_uzs' => 16000])->assertOk();
        $this->assertSame('4.000', $capped->fresh()?->billable_quantity, 'BR-QTY-006: the approved cap bills.');
    }

    public function test_a_line_added_by_an_edit_is_billed_at_its_own_markup(): void
    {
        // The order was placed under 15 %; the line added later under 12.5 %
        // (DL-37 (8)): 16 000 paid is 18 000, not 18 400.
        $line = $this->estimateLine(['markup_percent_snapshot' => '12.50']);

        $this->purchase($line, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 16000])->assertOk();

        $this->assertSame(18000, $line->fresh()?->billable_unit_price_uzs);
    }

    public function test_an_authorized_replacement_is_bought_from_its_price_and_the_original_drops_it(): void
    {
        $replacement = Product::factory()->unit(UnitCode::Piece)->create();
        $replaced = $this->replaced($this->fixedLine(), $replacement);

        // Left out, the product bought is the replacement, which needs the price
        // paid and meets the fixed line's 3 450 (BR-PRICE-005).
        $this->purchase($replaced, ['purchased_quantity' => '3'])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['actual_market_price_uzs']]);
        $this->purchase($replaced, ['purchased_quantity' => '3', 'actual_market_price_uzs' => 3001])
            ->assertStatus(409)->assertJsonPath('details.ceiling_customer_unit_price_uzs', 3450);
        $this->purchase($replaced, ['purchased_quantity' => '3', 'actual_market_price_uzs' => 2800])->assertOk();
        $bought = $replaced->fresh();
        $this->assertSame($replacement->id, $bought?->fulfilled_product_id);
        $this->assertSame(3220, $bought->billable_unit_price_uzs);
        $this->assertSame(SubstitutionResolution::Automatic, $bought->substitution_resolution);

        // The original found after all: its own price, its own snapshots, and
        // the replacement's authorization gone (DL-54 (4)).
        $approved = $this->replaced($this->fixedLine(), $replacement, approvedPrice: 3450);
        $this->purchase($approved, ['purchased_quantity' => '3', 'fulfilled_product_id' => strtoupper($approved->product_id)])->assertOk();
        $original = $approved->fresh();
        $this->assertSame($approved->product_id, $original?->fulfilled_product_id);
        $this->assertSame($approved->product_name_ru_snapshot, $original->fulfilled_product_name_ru_snapshot);
        $this->assertNull($original->substitution_resolution);
        $this->assertNull($original->approved_replacement_price_uzs);
        $this->assertSame(3450, $original->billable_unit_price_uzs);

        $this->purchase($this->fixedLine(), ['purchased_quantity' => '3', 'fulfilled_product_id' => $replacement->id])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['fulfilled_product_id']]);
    }

    public function test_a_price_approved_for_the_replacement_binds_the_replacement_and_never_the_original(): void
    {
        // An estimate line (bound 21 160) whose replacement the Customer
        // approved at 25 000 (DL-54 (5)).
        $replacement = Product::factory()->create();
        $original = $this->replaced($this->estimateLine(), $replacement, approvedPrice: 25000);

        $this->purchase($original, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 19000, 'fulfilled_product_id' => $original->product_id])
            ->assertStatus(409)
            ->assertJsonPath('details.ceiling_customer_unit_price_uzs', 21160)
            ->assertJsonPath('details.proposed_customer_unit_price_uzs', 21850);

        // 21 740 × 1.15 = 25 001: one UZS above what the Customer approved.
        $this->purchase($original, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 21740, 'fulfilled_product_id' => $replacement->id])
            ->assertStatus(409)
            ->assertJsonPath('details.ceiling_customer_unit_price_uzs', 25000);
        $this->purchase($original, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 21700, 'fulfilled_product_id' => $replacement->id])
            ->assertOk();
        $this->assertSame(24955, $original->fresh()->billable_unit_price_uzs);
        $this->assertSame($replacement->id, $original->fresh()->fulfilled_product_id);
    }

    public function test_the_replacement_of_an_estimate_meets_the_estimates_ceiling(): void
    {
        $replacement = Product::factory()->create();

        $above = $this->replaced($this->estimateLine(), $replacement);
        $this->purchase($above, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 18401])
            ->assertStatus(409)
            ->assertJsonPath('details', [
                'approval_type' => 'price_over_tolerance',
                'ceiling_customer_unit_price_uzs' => 21160,
                'proposed_customer_unit_price_uzs' => 21161,
            ]);

        $at = $this->replaced($this->estimateLine(), $replacement);
        $this->purchase($at, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 18400])->assertOk();
        $this->assertSame(21160, $at->fresh()->billable_unit_price_uzs);
    }

    public function test_a_retry_written_differently_is_the_same_purchase(): void
    {
        $line = $this->estimateLine();
        $key = (string) Str::uuid();

        $this->purchase($line, ['purchased_quantity' => '2', 'actual_market_price_uzs' => 16000, 'fulfilled_product_id' => $line->product_id], $key)->assertOk();
        $this->purchase($line, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 16000, 'fulfilled_product_id' => strtoupper($line->product_id)], $key)
            ->assertOk();

        $fixed = $this->fixedLine();
        $other = (string) Str::uuid();
        $this->purchase($fixed, ['purchased_quantity' => '3'], $other)->assertOk();
        $this->purchase($fixed, ['purchased_quantity' => '3', 'actual_market_price_uzs' => null], $other)->assertOk();

        $this->assertSame(2, OrderHistory::query()->where('event_type', OrderHistoryEvent::ItemPurchased)->count());
    }

    public function test_the_original_keeps_the_unit_it_was_ordered_in(): void
    {
        $line = $this->estimateLine();
        // An Admin changed the product to pieces after the order (DL-43 (2)).
        Product::query()->whereKey($line->product_id)->update(['unit_code' => UnitCode::Piece->value]);

        $this->purchase($line, ['purchased_quantity' => '2.500', 'actual_market_price_uzs' => 16000])->assertOk();

        $this->assertSame(UnitCode::Kg, $line->fresh()?->fulfilled_unit_code_snapshot);
    }

    public function test_what_is_sent_is_held_to_its_form(): void
    {
        $this->purchase($this->estimateLine(), ['purchased_quantity' => '2.000'])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['actual_market_price_uzs']]);
        $this->purchase($this->fixedLine(), ['purchased_quantity' => '2.5'])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['purchased_quantity']]);
        $this->purchase($this->estimateLine(), ['purchased_quantity' => 2, 'actual_market_price_uzs' => 16000])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['purchased_quantity']]);
        $this->purchase($this->estimateLine(), ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => '16000'])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['actual_market_price_uzs']]);
        $this->purchase($this->estimateLine(), ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 16000, 'billable_unit_price_uzs' => 1])
            ->assertStatus(422);

        $line = $this->estimateLine();
        $this->flushHeaders();
        $this->as($this->shopper)->postJson($this->url($line), ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 16000])
            ->assertStatus(400)->assertJsonPath('code', 'idempotency_key_required');

        $this->assertSame(0, OrderHistory::query()->count());
    }

    public function test_a_replay_answers_the_order_and_writes_nothing_again(): void
    {
        $line = $this->estimateLine();
        $key = (string) Str::uuid();
        $body = ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 16000];

        $this->purchase($line, $body, $key)->assertOk();
        $this->purchase($line, $body, $key)->assertOk()->assertJsonPath('data.items.0.status', 'purchased');
        $this->purchase($line, ['purchased_quantity' => '2.500', 'actual_market_price_uzs' => 16000], $key)
            ->assertStatus(409)->assertJsonPath('code', 'idempotency_key_reused');

        $this->assertSame(1, OrderHistory::query()->where('event_type', OrderHistoryEvent::ItemPurchased)->count());
        // Another key on the bought line meets it resolved (DL-54 (9)).
        $this->purchase($line, $body)->assertStatus(409)->assertJsonPath('code', 'item_already_resolved');
    }

    public function test_only_a_pending_line_of_an_order_being_shopped_by_the_caller_is_bought(): void
    {
        $body = ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 16000];

        $awaiting = $this->estimateLine(['status' => OrderItemStatus::AwaitingCustomer]);
        $this->purchase($awaiting, $body)->assertStatus(409)->assertJsonPath('code', 'item_already_resolved');

        $removed = $this->estimateLine();
        $removed->forceFill(['status' => OrderItemStatus::Removed, 'removed_reason_code' => 'customer_removed', 'removed_at' => now(), 'line_total_uzs' => 0])->save();
        $this->purchase($removed, $body)->assertStatus(404);

        $elsewhere = OrderItem::factory()->for(Order::factory()->shopping())->create();
        $this->as($this->shopper)->withHeader('Idempotency-Key', (string) Str::uuid())
            ->postJson("/api/v1/shopper/orders/{$this->order->id}/items/{$elsewhere->id}/purchase", $body)
            ->assertStatus(404);

        $notStarted = Order::factory()->state(['status' => OrderStatus::ShoppingAssigned])->create();
        OrderShopperAssignment::factory()->accepted()->create(['order_id' => $notStarted->id, 'shopper_id' => $this->shopper->id]);
        $this->purchase(OrderItem::factory()->for($notStarted)->create(), $body)
            ->assertStatus(409)->assertJsonPath('code', 'shopping_not_active');

        $someoneElse = User::factory()->role(Role::Shopper)->create();
        $this->as($someoneElse)->withHeader('Idempotency-Key', (string) Str::uuid())
            ->postJson($this->url($this->estimateLine()), $body)
            ->assertStatus(404);
    }

    public function test_the_customer_sees_the_price_to_pay_and_the_board_the_price_paid(): void
    {
        $replacement = Product::factory()->unit(UnitCode::Piece)->create();
        $line = $this->replaced($this->fixedLine(), $replacement);
        $this->purchase($line, ['purchased_quantity' => '3', 'actual_market_price_uzs' => 2800])->assertOk();

        $customer = $this->withToken($this->order->customer->createToken('c')->plainTextToken)
            ->getJson("/api/v1/customer/orders/{$this->order->id}")->assertOk()->json('data.items.0');
        $this->assertSame(3220, $customer['billable_unit_price_uzs']);
        $this->assertSame('3', $customer['billable_quantity']);
        $this->assertSame(9660, $customer['line_total_uzs']);
        $this->assertSame(['name_uz' => $replacement->name_uz, 'name_ru' => $replacement->name_ru], $customer['replacement']);
        $this->assertArrayNotHasKey('actual_market_price_uzs', $customer, 'BR-PRICE-001: never the market price.');
        $this->assertStringNotContainsString('2800', json_encode($customer, JSON_THROW_ON_ERROR));

        $board = $this->as(User::factory()->role(Role::Operator)->create())
            ->getJson("/api/v1/operations/orders/{$this->order->id}")->assertOk()->json('data.items.0');
        $this->assertSame('3', $board['purchased_quantity']);
        $this->assertSame(2800, $board['actual_market_price_uzs']);
        $this->assertSame(3220, $board['billable_unit_price_uzs']);
        $this->assertSame([
            'product_id' => $replacement->id,
            'name_uz' => $replacement->name_uz,
            'name_ru' => $replacement->name_ru,
            'substitution_resolution' => 'automatic',
        ], $board['replacement']);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function estimateLine(array $attributes = []): OrderItem
    {
        return OrderItem::factory()->for($this->order)->create($attributes);
    }

    /**
     * Three pieces at 3 000 market, 3 450 to the Customer.
     */
    private function fixedLine(): OrderItem
    {
        return OrderItem::factory()
            ->for($this->order)
            ->for(Product::factory()->fixed()->unit(UnitCode::Piece)->state(['market_price_uzs' => 3000]))
            ->create(['ordered_quantity' => '3']);
    }

    private function replaced(OrderItem $line, Product $replacement, ?int $approvedPrice = null): OrderItem
    {
        $line->forceFill([
            'fulfilled_product_id' => $replacement->id,
            'fulfilled_product_name_uz_snapshot' => $replacement->name_uz,
            'fulfilled_product_name_ru_snapshot' => $replacement->name_ru,
            'fulfilled_unit_code_snapshot' => $line->unit_code_snapshot,
            'substitution_resolution' => $approvedPrice === null ? SubstitutionResolution::Automatic : SubstitutionResolution::Approved,
            'approved_replacement_price_uzs' => $approvedPrice,
        ])->save();

        return $line;
    }

    /**
     * @param  array<string, mixed>  $body
     */
    private function purchase(OrderItem $line, array $body, ?string $key = null): TestResponse
    {
        return $this->as($this->shopper)
            ->withHeader('Idempotency-Key', $key ?? (string) Str::uuid())
            ->postJson($this->url($line), $body);
    }

    private function url(OrderItem $line): string
    {
        return "/api/v1/shopper/orders/{$line->order_id}/items/{$line->id}/purchase";
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
