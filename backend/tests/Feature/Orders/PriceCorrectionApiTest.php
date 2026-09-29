<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\Enums\HistoryActorType;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\Role;
use App\Models\Enums\SubstitutionResolution;
use App\Models\Enums\UnitCode;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\OrderItem;
use App\Models\OrderItemPriceCorrection;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * The Admin's price correction: `docs/09` section 45, `docs/02` section 8,
 * `BR-PRICE-006`, `DL-54` (18) and `DL-66`.
 *
 * The factory's lines: a kg estimate at 16 000 market, 18 400 to the
 * Customer under 15 %, ordered 2.000; the order's tolerance is 15 %, so the
 * estimate's bound is 21 160. The order's service fee is a fixed 5 000 and
 * its delivery fee 15 000.
 */
final class PriceCorrectionApiTest extends TestCase
{
    use RefreshDatabase;

    private User $admin;

    private User $shopper;

    private Order $order;

    protected function setUp(): void
    {
        parent::setUp();

        $this->admin = User::factory()->role(Role::Admin)->create();
        $this->shopper = User::factory()->role(Role::Shopper)->create();
        $this->order = Order::factory()->shopping()->create();
        $this->order->shopperAssignments()->update(['shopper_id' => $this->shopper->id]);
    }

    public function test_an_estimate_line_is_corrected_while_shopping(): void
    {
        $line = $this->estimateLine();
        $this->buy($line, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 17000]);
        $operator = User::factory()->role(Role::Operator)->create();
        $this->as($operator)->getJson("/api/v1/operations/orders/{$this->order->id}")->assertJsonPath('data.totals.total_uzs', 39100 + 5000 + 15000);

        $data = $this->correct($line, ['actual_market_price_uzs' => 16500, 'reason' => 'Опечатка в цене'])->assertOk()->json('data');
        $this->assertSame([37950 + 5000 + 15000, 'estimate'], [$data['totals']['total_uzs'], $data['totals']['total_kind']], 'Before completion the totals follow the line.');

        $bought = $line->fresh();
        $this->assertSame([16500, 18975, 37950], [$bought?->actual_market_price_uzs, $bought->billable_unit_price_uzs, $bought->line_total_uzs], 'half_up(16 500 × 1.15) = 18 975, twice.');
        $this->assertSame(18975, collect($data['items'])->firstWhere('id', $line->id)['billable_unit_price_uzs']);
        $this->assertNull($this->order->fresh()?->final_total_uzs, 'No final amounts before completion.');

        $correction = OrderItemPriceCorrection::query()->sole();
        $this->assertSame(
            [$line->id, 17000, 16500, 19550, 18975, $this->admin->id, 'Опечатка в цене'],
            [$correction->order_item_id, $correction->old_actual_market_price_uzs, $correction->new_actual_market_price_uzs, $correction->old_billable_unit_price_uzs, $correction->new_billable_unit_price_uzs, $correction->corrected_by_user_id, $correction->reason],
        );
        $row = OrderHistory::query()->where('event_type', OrderHistoryEvent::PriceCorrected)->sole();
        $this->assertSame([HistoryActorType::User, $this->admin->id, 'Опечатка в цене', null], [$row->actor_type, $row->actor_user_id, $row->note, $row->to_status]);
        $this->assertEquals([
            'item_id' => $line->id,
            'correction_id' => $correction->id,
            'old_actual_market_price_uzs' => 17000,
            'new_actual_market_price_uzs' => 16500,
            'old_billable_unit_price_uzs' => 19550,
            'new_billable_unit_price_uzs' => 18975,
            'line_total_uzs' => 37950,
        ], $row->details);

        // The current price again is a natural repeat.
        $this->correct($line, ['actual_market_price_uzs' => 16500, 'reason' => 'Ещё раз'])->assertOk();
        $this->assertSame(1, OrderItemPriceCorrection::query()->count());
        $this->assertSame(1, OrderHistory::query()->where('event_type', OrderHistoryEvent::PriceCorrected)->count());
    }

    public function test_a_replacement_corrected_after_completion_recomputes_the_final_amounts(): void
    {
        $replaced = $this->replaced($this->fixedLine());
        $this->buy($replaced, ['purchased_quantity' => '3', 'actual_market_price_uzs' => 2800]);
        $this->buy($this->estimateLine(), ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 16000]);
        $this->as($this->shopper)->withHeader('Idempotency-Key', (string) Str::uuid())
            ->postJson("/api/v1/shopper/orders/{$this->order->id}/complete")->assertOk();
        $this->assertSame([9660 + 36800, 66460], [$this->order->fresh()?->final_merchandise_subtotal_uzs, $this->order->fresh()->final_total_uzs]);

        $this->correct($replaced, ['actual_market_price_uzs' => 2900, 'reason' => 'Чек'])->assertOk()
            ->assertJsonPath('data.totals.total_uzs', 66805);

        // 3 × half_up(2 900 × 1.15) = 3 × 3 335 = 10 005.
        $order = $this->order->fresh();
        $this->assertSame([10005 + 36800, 5000, 66805], [$order?->final_merchandise_subtotal_uzs, $order->final_service_fee_uzs, $order->final_total_uzs]);
        $this->assertSame(66805, OrderHistory::query()->where('event_type', OrderHistoryEvent::PriceCorrected)->sole()->details['final_total_uzs']);
        $customer = User::query()->findOrFail($this->order->customer_id);
        $this->as($customer)->getJson("/api/v1/customer/orders/{$this->order->id}")->assertOk()
            ->assertJsonPath('data.totals.total_uzs', 66805)->assertJsonPath('data.totals.total_kind', 'final');

        // A replacement is held to its own bound: the fixed original's 3 450.
        $this->correct($replaced, ['actual_market_price_uzs' => 3001, 'reason' => 'Чек'])
            ->assertStatus(409)
            ->assertJsonPath('code', 'price_correction_above_ceiling')
            ->assertJsonPath('details', ['ceiling_customer_unit_price_uzs' => 3450, 'proposed_customer_unit_price_uzs' => 3451]);
    }

    public function test_only_a_price_paid_on_an_order_the_courier_has_not_taken_is_corrected(): void
    {
        $fixed = $this->fixedLine();
        $this->buy($fixed, ['purchased_quantity' => '3', 'actual_market_price_uzs' => 3900]);
        $this->correct($fixed, ['actual_market_price_uzs' => 3800, 'reason' => 'Чек'])
            ->assertStatus(409)->assertJsonPath('code', 'price_correction_not_applicable');
        $this->correct($this->estimateLine(), ['actual_market_price_uzs' => 16000, 'reason' => 'Чек'])
            ->assertStatus(409)->assertJsonPath('code', 'price_correction_not_applicable');

        $estimate = $this->estimateLine();
        $this->buy($estimate, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 16000]);
        $this->correct($estimate, ['actual_market_price_uzs' => 18401, 'reason' => 'Чек'])
            ->assertStatus(409)
            ->assertJsonPath('code', 'price_correction_above_ceiling')
            ->assertJsonPath('details', ['ceiling_customer_unit_price_uzs' => 21160, 'proposed_customer_unit_price_uzs' => 21161]);
        $this->correct($estimate, ['actual_market_price_uzs' => 18400, 'reason' => 'Чек'])->assertOk();

        foreach ([Order::factory()->onTheWay(), Order::factory()->completed(), Order::factory()->shopping()->cancelled()] as $factory) {
            $order = $factory->create();
            $line = OrderItem::factory()->for($order)->purchased()->create();
            $this->correct($line, ['actual_market_price_uzs' => 15000, 'reason' => 'Чек'])
                ->assertStatus(409)->assertJsonPath('code', 'price_correction_locked');
        }
        // The order's state is asked before the line's.
        $onTheWay = Order::factory()->onTheWay()->create();
        $this->correct(OrderItem::factory()->for($onTheWay)->create(), ['actual_market_price_uzs' => 15000, 'reason' => 'Чек'])
            ->assertJsonPath('code', 'price_correction_locked');

        $this->assertSame(1, OrderItemPriceCorrection::query()->count());
    }

    public function test_each_bound_and_quantity_is_the_purchases_own(): void
    {
        // An approved ceiling raises the original's bound: 25 000.
        $ceiling = $this->estimateLine(['approved_unit_price_ceiling_uzs' => 25000]);
        $this->buy($ceiling, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 16000]);
        $this->correct($ceiling, ['actual_market_price_uzs' => 21739, 'reason' => 'Чек'])->assertOk();
        $this->correct($ceiling, ['actual_market_price_uzs' => 21740, 'reason' => 'Чек'])
            ->assertStatus(409)->assertJsonPath('details.ceiling_customer_unit_price_uzs', 25000);

        // A replacement approved at a price is held to it, below or above the automatic 21 160.
        $below = $this->replaced($this->estimateLine(), approvedPrice: 20000);
        $this->buy($below, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 16000]);
        $this->correct($below, ['actual_market_price_uzs' => 17392, 'reason' => 'Чек'])
            ->assertStatus(409)->assertJsonPath('code', 'price_correction_above_ceiling')->assertJsonPath('details.ceiling_customer_unit_price_uzs', 20000);
        $above = $this->replaced($this->estimateLine(), approvedPrice: 30000);
        $this->buy($above, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 16000]);
        $this->correct($above, ['actual_market_price_uzs' => 26000, 'reason' => 'Чек'])->assertOk();
        $this->assertSame(29900, $above->fresh()?->billable_unit_price_uzs);

        // The excess is not billed: 2.5 bought, 2 × half_up(16 500 × 1.15).
        $excess = $this->estimateLine();
        $this->buy($excess, ['purchased_quantity' => '2.500', 'actual_market_price_uzs' => 16000]);
        $this->correct($excess, ['actual_market_price_uzs' => 16500, 'reason' => 'Чек'])->assertOk();
        $this->assertSame(37950, $excess->fresh()?->line_total_uzs);

        // A line added under 10 % keeps its own markup: half_up(16 500 × 1.10).
        $own = $this->estimateLine(['markup_percent_snapshot' => '10.00', 'customer_unit_price_uzs_snapshot' => 17600]);
        $this->buy($own, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 16000]);
        $this->correct($own, ['actual_market_price_uzs' => 16500, 'reason' => 'Чек'])->assertOk();
        $this->assertSame(18150, $own->fresh()?->billable_unit_price_uzs);
    }

    public function test_a_correction_is_open_until_the_courier_sets_off_and_a_retry_learns_it(): void
    {
        $assigned = Order::factory()->deliveryAssigned()->create();
        $line = OrderItem::factory()->for($assigned)->purchased()->create();
        // Its one bought line, 2 × half_up(15 000 × 1.15), then the fee and the delivery.
        $this->correct($line, ['actual_market_price_uzs' => 15000, 'reason' => 'Чек'])->assertOk()
            ->assertJsonPath('data.totals.total_uzs', 34500 + 5000 + 15000);

        // The Courier sets off; the retry of that correction is still a repeat.
        $assigned->forceFill(['status' => 'on_the_way', 'on_the_way_at' => now()])->save();
        $this->correct($line, ['actual_market_price_uzs' => 15000, 'reason' => 'Чек'])->assertOk();
        $this->correct($line, ['actual_market_price_uzs' => 14000, 'reason' => 'Чек'])
            ->assertStatus(409)->assertJsonPath('code', 'price_correction_locked');
        $this->assertSame(1, OrderItemPriceCorrection::query()->count());

        // No online order is re-priced before Wave 5 (DL-54 (1)).
        $online = Order::factory()->online()->readyForDelivery()->create();
        $this->correct(OrderItem::factory()->for($online)->purchased()->create(), ['actual_market_price_uzs' => 15000, 'reason' => 'Чек'])
            ->assertStatus(409)->assertJsonPath('code', 'price_correction_locked');
    }

    public function test_only_the_admin_corrects_a_line_of_the_order_named(): void
    {
        $line = $this->estimateLine();
        $this->buy($line, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 17000]);

        foreach ([Role::Operator, Role::Manager, Role::Shopper, Role::Courier, Role::Customer] as $role) {
            $this->correct($line, ['actual_market_price_uzs' => 16000, 'reason' => 'Чек'], User::factory()->role($role)->create())->assertStatus(403);
        }

        $elsewhere = Order::factory()->shopping()->create();
        $this->as($this->admin)->postJson("/api/v1/admin/orders/{$elsewhere->id}/items/{$line->id}/price-correction", ['actual_market_price_uzs' => 16000, 'reason' => 'Чек'])
            ->assertStatus(404);
        $this->as($this->admin)->postJson('/api/v1/admin/orders/'.Str::uuid()."/items/{$line->id}/price-correction", ['actual_market_price_uzs' => 16000, 'reason' => 'Чек'])
            ->assertStatus(404);

        foreach ([
            ['actual_market_price_uzs' => 16000],
            ['actual_market_price_uzs' => 16000, 'reason' => '   '],
            ['actual_market_price_uzs' => 16000, 'reason' => str_repeat('a', 301)],
            ['actual_market_price_uzs' => 0, 'reason' => 'Чек'],
            ['actual_market_price_uzs' => '16000', 'reason' => 'Чек'],
            ['reason' => 'Чек'],
            ['actual_market_price_uzs' => 16000, 'reason' => 'Чек', 'extra' => true],
        ] as $body) {
            $this->correct($line, $body)->assertStatus(422);
        }
        $this->assertSame(0, OrderItemPriceCorrection::query()->count());
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

    private function replaced(OrderItem $line, ?int $approvedPrice = null): OrderItem
    {
        $replacement = Product::factory()->unit($line->unit_code_snapshot)->create();
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
    private function buy(OrderItem $line, array $body): void
    {
        $this->as($this->shopper)
            ->withHeader('Idempotency-Key', (string) Str::uuid())
            ->postJson("/api/v1/shopper/orders/{$line->order_id}/items/{$line->id}/purchase", $body)
            ->assertOk();
    }

    /**
     * @param  array<string, mixed>  $body
     */
    private function correct(OrderItem $line, array $body, ?User $as = null): TestResponse
    {
        return $this->as($as ?? $this->admin)->postJson("/api/v1/admin/orders/{$line->order_id}/items/{$line->id}/price-correction", $body);
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
