<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Exceptions\ApiException;
use App\Models\CustomerApproval;
use App\Models\Enums\ApprovalStatus;
use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\ItemRemovedReason;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\Role;
use App\Models\Enums\ServiceFeeMode;
use App\Models\Enums\SubstitutionResolution;
use App\Models\Enums\UnitCode;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\OrderItem;
use App\Models\OrderShopperAssignment;
use App\Models\Product;
use App\Models\User;
use App\Modules\Orders\ShopperOrders;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

/**
 * Completing the shopping: `docs/09` section 35, `docs/04` section 22,
 * `BR-MONEY-003` to `BR-MONEY-006`, `DL-54` (3), (7), (23) and `DL-61`.
 *
 * The factory's lines: a kg estimate at 16 000 market, 18 400 to the
 * Customer under 15 %, ordered 2.000; the order's tolerance is 15 %, its
 * service fee a fixed 5 000 and its delivery fee 15 000.
 */
final class CompleteShoppingApiTest extends TestCase
{
    use RefreshDatabase;

    private User $shopper;

    private Order $order;

    protected function setUp(): void
    {
        parent::setUp();

        Carbon::setTestNow(CarbonImmutable::parse('2026-09-29T08:00:00Z'));
        $this->shopper = User::factory()->role(Role::Shopper)->create();
        $this->order = Order::factory()->shopping()->create();
        $this->order->shopperAssignments()->update(['shopper_id' => $this->shopper->id]);
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();

        parent::tearDown();
    }

    /**
     * @return array<string, array{0: array<string, mixed>, 1: int, 2: int}>
     */
    public static function feeRules(): array
    {
        return [
            'a fixed fee' => [['service_fee_mode_snapshot' => ServiceFeeMode::Fixed, 'service_fee_fixed_uzs_snapshot' => 5000, 'service_fee_percent_snapshot' => null], 5000, 143510],
            // 123 510 × 15 % is 18 526.5: half up is 18 527, where rounding
            // half to even would give 18 526 (BR-MONEY-005).
            'a percentage' => [['service_fee_mode_snapshot' => ServiceFeeMode::Percentage, 'service_fee_fixed_uzs_snapshot' => null, 'service_fee_percent_snapshot' => '15.00'], 18527, 157037],
        ];
    }

    /**
     * Each kind of line bought through the Shopper's own actions, so the
     * amounts are the ones the database's checks hold (`DL-38` (2)).
     *
     * @param  array<string, mixed>  $feeRule
     */
    #[DataProvider('feeRules')]
    public function test_completion_stores_the_final_amounts_of_what_was_bought(array $feeRule, int $fee, int $total): void
    {
        $this->order->forceFill($feeRule)->save();

        // A fixed line at its snapshot: 3 × 3 450.
        $this->buy($this->fixedLine(), ['purchased_quantity' => '3', 'actual_market_price_uzs' => 3900]);
        // An estimate from the price paid: 2 × half_up(17 000 × 1.15).
        $this->buy($this->estimateLine(), ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 17000]);
        // The excess is not billed: 2.6 bought, 2 × 18 400.
        $this->buy($this->estimateLine(), ['purchased_quantity' => '2.600', 'actual_market_price_uzs' => 16000]);
        // An approved cap bills: 1.5 × 18 400.
        $this->buy($this->estimateLine(['approved_quantity_cap' => '1.500']), ['purchased_quantity' => '1.500', 'actual_market_price_uzs' => 16000]);
        // A replacement from its price paid: 3 × half_up(2 800 × 1.15).
        $this->buy($this->replaced($this->fixedLine()), ['purchased_quantity' => '3', 'actual_market_price_uzs' => 2800]);
        // Nothing for a line not found, nor for one the Customer took out.
        $this->as($this->shopper)->postJson($this->itemUrl($this->estimateLine(), 'unavailable'))->assertOk();
        OrderItem::factory()->for($this->order)->removed(ItemRemovedReason::CustomerRemoved)->create();

        $data = $this->complete()->assertOk()->json('data');

        $this->assertSame('ready_for_delivery', $data['status']);
        $this->assertNull($data['customer_phone'], 'The phone is for shopping only (interview 7.3).');
        $assignment = OrderShopperAssignment::query()->where('order_id', $this->order->id)->sole();
        $this->assertSame($assignment->id, $data['assignment']['id']);
        $this->assertFalse($data['can_accept']);
        $this->assertFalse($data['can_start']);

        $order = $this->order->fresh();
        $this->assertSame(OrderStatus::ReadyForDelivery, $order?->status);
        $this->assertSame(10350 + 39100 + 36800 + 27600 + 9660, $order->final_merchandise_subtotal_uzs);
        $this->assertSame($fee, $order->final_service_fee_uzs);
        $this->assertSame($total, $order->final_total_uzs);
        $this->assertTrue($order->shopping_completed_at?->equalTo(now()));
        $this->assertTrue($order->ready_for_delivery_at?->equalTo(now()));

        $this->assertSame(AssignmentEndReason::Completed, $assignment->ended_reason);
        $this->assertTrue($assignment->ended_at?->equalTo(now()));
        $this->assertTrue($assignment->completed_at?->equalTo(now()));

        $row = OrderHistory::query()->where('order_id', $this->order->id)->where('event_type', OrderHistoryEvent::StatusChanged)->sole();
        $this->assertSame(OrderStatus::Shopping, $row->from_status);
        $this->assertSame(OrderStatus::ReadyForDelivery, $row->to_status);
        $this->assertSame(HistoryActorType::User, $row->actor_type);
        $this->assertSame($this->shopper->id, $row->actor_user_id);
        $this->assertEquals([
            'assignment_id' => $assignment->id,
            'final_merchandise_subtotal_uzs' => 123510,
            'final_service_fee_uzs' => $fee,
            'final_total_uzs' => $total,
        ], $row->details);

        // From now on everyone reads the stored amounts (DL-37 (10)).
        $expected = [
            'merchandise_subtotal_uzs' => 123510,
            'service_fee_uzs' => $fee,
            'delivery_fee_uzs' => 15000,
            'total_uzs' => $total,
            'total_kind' => 'final',
        ];
        $customer = User::query()->findOrFail($this->order->customer_id);
        $this->as($customer)->getJson("/api/v1/customer/orders/{$this->order->id}")->assertOk()->assertJsonPath('data.totals', $expected);
        $operator = User::factory()->role(Role::Operator)->create();
        $board = $this->as($operator)->getJson("/api/v1/operations/orders/{$this->order->id}")->assertOk()->json('data.totals');
        $this->assertSame($total, $board['total_uzs']);
        $this->assertSame('final', $board['total_kind']);
    }

    public function test_the_order_leaves_the_shoppers_hands_and_a_replay_still_answers_it(): void
    {
        $this->buy($this->estimateLine(), ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 16000]);
        $key = (string) Str::uuid();

        $first = $this->complete($key)->assertOk()->json();

        // A retry after a lost answer learns the outcome (DL-54 (3)).
        $this->assertSame($first, $this->complete($key)->assertOk()->json());
        $this->assertSame(1, OrderHistory::query()->where('event_type', OrderHistoryEvent::StatusChanged)->count());

        // Anything else needs a current assignment.
        $this->complete()->assertStatus(404);
        $this->as($this->shopper)->getJson("/api/v1/shopper/orders/{$this->order->id}")->assertStatus(404);
        $this->assertSame([], $this->as($this->shopper)->getJson('/api/v1/shopper/orders')->assertOk()->json('data'));

        // Only the Shopper who completed it reaches the order this way.
        try {
            ShopperOrders::completedBy(User::factory()->role(Role::Shopper)->create(), $this->order->id);
            $this->fail('Another Shopper reached the order.');
        } catch (ApiException $refused) {
            $this->assertSame(404, $refused->status());
        }

        // Once another Shopper holds the order, the replay no longer reaches it.
        OrderShopperAssignment::factory()->create(['order_id' => $this->order->id, 'assigned_at' => now()->addMinute()]);
        $this->complete($key)->assertStatus(404);
    }

    public function test_every_line_must_be_bought_or_removed_and_no_question_open(): void
    {
        $bought = $this->estimateLine();
        $this->buy($bought, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 16000]);
        // A question still pending counts even on a line that no longer waits,
        // a state no action leaves but the contract names (docs/09 section 35).
        $settled = $this->estimateLine();
        $this->buy($settled, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 16000]);
        $stray = CustomerApproval::factory()->create(['order_item_id' => $settled->id, 'attention_at' => now()->addMinutes(10), 'expires_at' => now()->addMinutes(30)]);
        $pending = $this->estimateLine();
        $waiting = CustomerApproval::factory()->create([
            'order_item_id' => OrderItem::factory()->for($this->order)->awaitingCustomer()->create()->id,
            'attention_at' => now()->subMinutes(5),
            'expires_at' => now()->addMinutes(15),
        ]);
        $overdue = CustomerApproval::factory()->create([
            'order_item_id' => OrderItem::factory()->for($this->order)->awaitingCustomer()->create()->id,
            'attention_at' => now()->subMinutes(21),
            'expires_at' => now()->subMinute(),
        ]);
        $key = (string) Str::uuid();

        $refused = $this->complete($key)->assertStatus(409)->assertJsonPath('code', 'shopping_incomplete');
        $this->assertEqualsCanonicalizing([$pending->id, $waiting->order_item_id, $overdue->order_item_id, $settled->id], $refused->json('details.item_ids'));
        $stray->forceFill(['status' => ApprovalStatus::Cancelled, 'resolved_at' => now()])->save();

        $this->assertSame(OrderStatus::Shopping, $this->order->fresh()?->status);
        $this->assertNull($this->order->fresh()->final_total_uzs);
        $this->assertNull(OrderShopperAssignment::query()->where('order_id', $this->order->id)->sole()->ended_at);
        $this->assertSame(0, OrderHistory::query()->where('event_type', OrderHistoryEvent::StatusChanged)->count());
        $this->assertSame(ApprovalStatus::Expired, $overdue->fresh()?->status, 'Expired on the way, and kept (DL-60 (1)).');
        $this->assertSame(1, OrderHistory::query()->where('event_type', OrderHistoryEvent::ApprovalExpired)->count());

        // A refusal frees the key (DL-39 (2)): the same key completes once
        // the lines are settled.
        $this->as($this->shopper)->postJson($this->itemUrl($pending, 'unavailable'))->assertOk();
        Carbon::setTestNow(now()->addMinutes(16));
        $operator = User::factory()->role(Role::Operator)->create();
        foreach ([$waiting, $overdue] as $question) {
            $this->as($operator)->postJson("/api/v1/operations/approvals/{$question->id}/resolve-expired", ['resolution' => 'remove_item'])->assertOk();
        }
        $this->complete($key)->assertOk()->assertJsonPath('data.status', 'ready_for_delivery');
        $this->assertSame(2 * 36800, $this->order->fresh()?->final_merchandise_subtotal_uzs);
    }

    public function test_only_the_shopper_shopping_the_order_completes_it(): void
    {
        $this->buy($this->estimateLine(), ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 16000]);

        $this->flushHeaders();
        $this->as($this->shopper)->postJson("/api/v1/shopper/orders/{$this->order->id}/complete")
            ->assertStatus(400)->assertJsonPath('code', 'idempotency_key_required');
        $this->complete(as: User::factory()->role(Role::Shopper)->create())->assertStatus(404);
        $this->complete(order: (string) Str::uuid())->assertStatus(404);
        foreach ([Role::Customer, Role::Courier, Role::Operator] as $role) {
            $this->complete(as: User::factory()->role($role)->create())->assertStatus(403);
        }
        $this->as($this->shopper)->withHeader('Idempotency-Key', (string) Str::uuid())
            ->postJson("/api/v1/shopper/orders/{$this->order->id}/complete", ['note' => 'done'])->assertStatus(422);

        $notStarted = Order::factory()->shoppingAssigned()->create();
        $notStarted->shopperAssignments()->update(['shopper_id' => $this->shopper->id, 'accepted_at' => now()]);
        $this->complete(order: $notStarted->id)->assertStatus(409)->assertJsonPath('code', 'shopping_not_active');

        // A shopping order is completed only by the Shopper who started it.
        $unstarted = Order::factory()->shopping()->create();
        $unstarted->shopperAssignments()->update(['shopper_id' => $this->shopper->id, 'started_at' => null]);
        $this->complete(order: $unstarted->id)->assertStatus(409)->assertJsonPath('code', 'shopping_not_active');

        $this->complete()->assertOk();
    }

    public function test_an_order_completion_cannot_settle_is_refused_rather_than_sent_out(): void
    {
        // No online order exists before Wave 5 (DL-54 (1)); one met here is
        // not sent out unpaid.
        $online = Order::factory()->online()->shopping()->create();
        $online->shopperAssignments()->update(['shopper_id' => $this->shopper->id]);
        $line = OrderItem::factory()->for($online)->create();
        $this->buy($line, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 16000]);
        $this->complete(order: $online->id)->assertStatus(409)->assertJsonPath('code', 'order_state_conflict');
        $this->assertSame(OrderStatus::Shopping, $online->fresh()?->status);

        // Nothing bought never reaches completion (DL-54 (7)); an order with
        // every line removed yet not cancelled is not billed its fees alone.
        OrderItem::factory()->for($this->order)->removed(ItemRemovedReason::Unavailable)->create();
        $this->complete()->assertStatus(409)->assertJsonPath('code', 'order_state_conflict');
        $this->assertSame(OrderStatus::Shopping, $this->order->fresh()?->status);
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

    private function replaced(OrderItem $line): OrderItem
    {
        $replacement = Product::factory()->unit(UnitCode::Piece)->create();
        $line->forceFill([
            'fulfilled_product_id' => $replacement->id,
            'fulfilled_product_name_uz_snapshot' => $replacement->name_uz,
            'fulfilled_product_name_ru_snapshot' => $replacement->name_ru,
            'fulfilled_unit_code_snapshot' => $line->unit_code_snapshot,
            'substitution_resolution' => SubstitutionResolution::Automatic,
        ])->save();

        return $line;
    }

    /**
     * @param  array<string, mixed>  $body
     */
    private function buy(OrderItem $line, array $body): void
    {
        $this->as($this->shopper)
            ->withHeader('Idempotency-Key', (string) Str::uuid())
            ->postJson($this->itemUrl($line, 'purchase'), $body)
            ->assertOk();
    }

    private function complete(?string $key = null, ?User $as = null, ?string $order = null): TestResponse
    {
        return $this->as($as ?? $this->shopper)
            ->withHeader('Idempotency-Key', $key ?? (string) Str::uuid())
            ->postJson('/api/v1/shopper/orders/'.($order ?? $this->order->id).'/complete');
    }

    private function itemUrl(OrderItem $line, string $action): string
    {
        return "/api/v1/shopper/orders/{$line->order_id}/items/{$line->id}/{$action}";
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
