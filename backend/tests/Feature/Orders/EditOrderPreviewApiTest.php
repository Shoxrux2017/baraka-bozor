<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\BusinessSettings;
use App\Models\Enums\PriceMode;
use App\Models\Enums\ServiceFeeMode;
use App\Models\Enums\UnitCode;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * The preview of an order edit, `docs/09` section 21, `DL-132` (1), (2): the
 * edit's own plan and refusals, priced with nothing locked or written. The
 * order holds tomatoes 2.5 kg at 14 000 and bread 3 at 3 000 (a fixed fee of
 * 5 000, delivery 15 000, so 64 000 now); the settings are a 25 % markup and
 * no minimum.
 */
final class EditOrderPreviewApiTest extends TestCase
{
    use RefreshDatabase;

    private User $customer;

    private Order $order;

    private OrderItem $tomatoLine;

    private OrderItem $breadLine;

    protected function setUp(): void
    {
        parent::setUp();

        DB::table('business_settings')->where('id', BusinessSettings::SINGLETON_ID)->update([
            'markup_percent' => '25.00',
            'minimum_order_uzs' => null,
        ]);

        $this->customer = User::factory()->customer()->create();
        $this->order = Order::factory()->shoppingAssigned()->create(['customer_id' => $this->customer->id]);
        $this->tomatoLine = OrderItem::factory()->for($this->order)->for(Product::factory()->create())->create([
            'ordered_quantity' => '2.500',
            'customer_unit_price_uzs_snapshot' => 14000,
        ]);
        $this->breadLine = OrderItem::factory()->fixed()->for($this->order)->for(Product::factory()->unit(UnitCode::Piece)->create())->create([
            'ordered_quantity' => '3.000',
            'customer_unit_price_uzs_snapshot' => 3000,
        ]);
    }

    public function test_the_preview_prices_the_list_without_writing(): void
    {
        $added = Product::factory()->unit(UnitCode::Piece)->create(['market_price_uzs' => 6400]);
        $itemsBefore = OrderItem::query()->orderBy('id')->get()->toArray();
        $updatedAt = $this->order->fresh()?->updated_at;

        $this->preview([
            ['product_id' => $this->tomatoLine->product_id, 'quantity' => '3'],
            ['product_id' => $added->id, 'quantity' => '1'],
        ])->assertOk()->assertExactJson(['data' => [
            'merchandise_subtotal_uzs' => 50000,
            'service_fee_uzs' => 5000,
            'delivery_fee_uzs' => 15000,
            'total_uzs' => 70000,
            'total_kind' => 'estimate',
            'total_before_uzs' => 64000,
            'total_change_uzs' => 6000,
            'minimum_order_uzs' => null,
            'minimum_order_shortfall_uzs' => 0,
        ]]);

        $this->assertSame($itemsBefore, OrderItem::query()->orderBy('id')->get()->toArray());
        $this->assertSame(0, OrderHistory::query()->count());
        $this->assertEquals($updatedAt, $this->order->fresh()?->updated_at);
    }

    public function test_a_percent_service_fee_follows_the_previewed_goods(): void
    {
        $this->order->forceFill([
            'service_fee_mode_snapshot' => ServiceFeeMode::Percentage,
            'service_fee_fixed_uzs_snapshot' => null,
            'service_fee_percent_snapshot' => '5.00',
        ])->save();

        // 3 × 14 000 = 42 000; 5 % of it is 2 100. Now: 44 000 + 2 200 + 15 000.
        $this->preview([['product_id' => $this->tomatoLine->product_id, 'quantity' => '3']])
            ->assertOk()
            ->assertJsonPath('data.merchandise_subtotal_uzs', 42000)
            ->assertJsonPath('data.service_fee_uzs', 2100)
            ->assertJsonPath('data.total_uzs', 59100)
            ->assertJsonPath('data.total_before_uzs', 61200)
            ->assertJsonPath('data.total_change_uzs', -2100);

        // 5 % of 42 012 is 2 100.6, rounded half up to 2 101.
        $this->tomatoLine->forceFill(['customer_unit_price_uzs_snapshot' => 14004])->save();
        $this->preview([['product_id' => $this->tomatoLine->product_id, 'quantity' => '3']])
            ->assertJsonPath('data.merchandise_subtotal_uzs', 42012)
            ->assertJsonPath('data.service_fee_uzs', 2101);
    }

    public function test_the_shortfall_is_answered_only_for_an_edit_that_lowers_the_goods(): void
    {
        DB::table('business_settings')->update(['minimum_order_uzs' => 60000]);
        $tomatoes = $this->tomatoLine->product_id;
        $bread = $this->breadLine->product_id;

        // Unchanged (44 000) and raised (51 000) lists are not refused.
        $this->preview([['product_id' => $tomatoes, 'quantity' => '2.5'], ['product_id' => $bread, 'quantity' => '3']])
            ->assertOk()
            ->assertJsonPath('data.minimum_order_uzs', 60000)
            ->assertJsonPath('data.minimum_order_shortfall_uzs', 0);
        $this->preview([['product_id' => $tomatoes, 'quantity' => '3'], ['product_id' => $bread, 'quantity' => '3']])
            ->assertJsonPath('data.minimum_order_shortfall_uzs', 0);

        // A lowered list (2 × 14 000 + 3 000 = 31 000) is short by 29 000.
        $this->preview([['product_id' => $tomatoes, 'quantity' => '2'], ['product_id' => $bread, 'quantity' => '1']])
            ->assertOk()
            ->assertJsonPath('data.merchandise_subtotal_uzs', 31000)
            ->assertJsonPath('data.minimum_order_shortfall_uzs', 29000);

        // A lowered list that still reaches the minimum is not short.
        DB::table('business_settings')->update(['minimum_order_uzs' => 30000]);
        $this->preview([['product_id' => $tomatoes, 'quantity' => '2'], ['product_id' => $bread, 'quantity' => '1']])
            ->assertJsonPath('data.minimum_order_shortfall_uzs', 0);

        DB::table('business_settings')->update(['minimum_order_uzs' => null]);
        $this->preview([['product_id' => $tomatoes, 'quantity' => '1']])
            ->assertJsonPath('data.minimum_order_uzs', null)
            ->assertJsonPath('data.minimum_order_shortfall_uzs', 0);
    }

    public function test_an_estimate_line_makes_the_preview_an_estimate(): void
    {
        $bread = $this->breadLine->product_id;
        $this->tomatoLine->forceFill(['price_mode_snapshot' => PriceMode::Fixed])->save();

        $this->preview([['product_id' => $this->tomatoLine->product_id, 'quantity' => '1'], ['product_id' => $bread, 'quantity' => '1']])
            ->assertOk()->assertJsonPath('data.total_kind', 'final');

        $estimate = Product::factory()->create(['price_mode' => PriceMode::Estimate]);
        $this->preview([['product_id' => $bread, 'quantity' => '1'], ['product_id' => $estimate->id, 'quantity' => '1']])
            ->assertOk()->assertJsonPath('data.total_kind', 'estimate');
    }

    public function test_the_preview_is_refused_as_the_edit_is(): void
    {
        $line = [['product_id' => $this->tomatoLine->product_id, 'quantity' => '3']];

        $hidden = Product::factory()->archived()->create();
        $this->preview([...$line, ['product_id' => $hidden->id, 'quantity' => '1']])
            ->assertStatus(409)->assertJsonPath('code', 'product_unavailable')->assertJsonPath('details.product_ids', [$hidden->id]);

        $this->preview([['product_id' => $this->tomatoLine->product_id, 'quantity' => '1.2345']])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['items.0.quantity']]);
        $this->withToken($this->token())->postJson($this->url(), ['items' => $line, 'delivery_time_note' => null])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['delivery_time_note']]);

        $other = User::factory()->customer()->create();
        $this->withToken($other->createToken('t')->plainTextToken)->postJson($this->url(), ['items' => $line])->assertStatus(404);

        $this->flushHeaders()->postJson($this->url(), ['items' => $line])->assertStatus(401);

        $this->order->currentShopperAssignment?->forceFill(['accepted_at' => now(), 'started_at' => now()])->save();
        $this->preview($line)->assertStatus(409)->assertJsonPath('code', 'order_editing_locked');
    }

    public function test_the_preview_has_its_own_throttle(): void
    {
        $line = [['product_id' => $this->tomatoLine->product_id, 'quantity' => '3']];
        $token = $this->token();

        for ($i = 0; $i < 30; $i++) {
            $this->withToken($token)->postJson($this->url(), ['items' => $line])->assertOk();
        }
        $this->withToken($token)
            ->putJson('/api/v1/customer/orders/'.$this->order->id.'/items', ['items' => $line, 'delivery_time_note' => null])
            ->assertOk();

        for ($i = 30; $i < 120; $i++) {
            $this->withToken($token)->postJson($this->url(), ['items' => $line])->assertOk();
        }
        $this->withToken($token)->postJson($this->url(), ['items' => $line])
            ->assertStatus(429)->assertJsonPath('code', 'rate_limited');
    }

    public function test_thirty_ratings_do_not_use_up_the_edits(): void
    {
        $line = [['product_id' => $this->tomatoLine->product_id, 'quantity' => '3']];
        $token = $this->token();

        // The rating has its own bucket (`order-rating`); whatever it answers,
        // its thirty calls leave the edit's thirty untouched.
        for ($i = 0; $i < 30; $i++) {
            $this->withToken($token)->postJson('/api/v1/customer/orders/'.$this->order->id.'/rating', ['stars' => 5]);
        }
        $this->withToken($token)
            ->putJson('/api/v1/customer/orders/'.$this->order->id.'/items', ['items' => $line, 'delivery_time_note' => null])
            ->assertOk();
    }

    /**
     * @param  list<array<string, mixed>>  $items
     */
    private function preview(array $items): TestResponse
    {
        return $this->withToken($this->token())->postJson($this->url(), ['items' => $items]);
    }

    private function token(): string
    {
        return $this->customer->createToken('t')->plainTextToken;
    }

    private function url(): string
    {
        return '/api/v1/customer/orders/'.$this->order->id.'/items/preview';
    }
}
