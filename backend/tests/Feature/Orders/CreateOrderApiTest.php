<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\BusinessSettings;
use App\Models\Cart;
use App\Models\CartItem;
use App\Models\CustomerAddress;
use App\Models\Enums\CartStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\Role;
use App\Models\Enums\UnitCode;
use App\Models\IdempotencyKey;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\Product;
use App\Models\User;
use App\Modules\Orders\Checkout\CheckoutToken;
use App\Modules\Orders\CustomerCart;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * Order creation, `docs/09` section 19 and `docs/04` section 8: idempotent,
 * bound to the checkout the Customer was shown, with every snapshot of
 * `docs/07` section 13, the cart converted and a new one opened. Settings: a
 * 15 % markup, a fixed fee of 5 000, delivery 15 000, a minimum of 50 000.
 */
final class CreateOrderApiTest extends TestCase
{
    use RefreshDatabase;

    private const PREVIEW = '/api/v1/customer/checkout/preview';

    private const ORDERS = '/api/v1/customer/orders';

    private User $customer;

    private CustomerAddress $address;

    private Product $tomatoes;

    private Product $bread;

    protected function setUp(): void
    {
        parent::setUp();

        DB::table('business_settings')->where('id', BusinessSettings::SINGLETON_ID)->update([
            'markup_percent' => '15.00',
            'service_fee_mode' => 'fixed',
            'service_fee_fixed_uzs' => 5000,
            'delivery_fee_uzs' => 15000,
            'minimum_order_uzs' => 50000,
            'opens_at' => '08:00',
            'closes_at' => '22:00',
            'service_centre_latitude' => '41.311081',
            'service_centre_longitude' => '69.240562',
            'service_radius_km' => '5.00',
        ]);
        $this->travelTo(CarbonImmutable::parse('2026-09-27 12:00:00', 'Asia/Tashkent'));

        $this->customer = User::factory()->customer()->create(['full_name' => 'Aziza Karimova']);
        $this->address = CustomerAddress::factory()->create([
            'customer_id' => $this->customer->id,
            'apartment' => '45',
            'landmark' => 'Metro yonida',
            'delivery_note' => 'Domofon 45',
        ]);
        $this->tomatoes = Product::factory()->create(['market_price_uzs' => 16000]);
        $this->bread = Product::factory()->fixed()->unit(UnitCode::Piece)->create(['market_price_uzs' => 3000]);
        $this->line($this->tomatoes, '3.000', 'Qizil bo\'lsin');
        $this->line($this->bread, '2.000');
    }

    public function test_an_order_is_created_with_every_snapshot_and_the_cart_is_converted(): void
    {
        $cart = CustomerCart::of($this->customer);
        $token = $this->token(['delivery_time_note' => 'После 18:00']);

        $data = $this->create($token)->assertCreated()->json('data');

        $this->assertSame([
            'id', 'order_number', 'status', 'payment_method', 'delivery_time_note', 'pending_approval_count', 'can_edit',
            'can_cancel_directly', 'can_request_cancellation', 'cancellation_request', 'items', 'totals', 'address', 'cancellation_reason_code',
            'payment', 'refunds', 'timestamps',
        ], array_keys($data));
        $this->assertGreaterThanOrEqual(1001, $data['order_number']);
        $this->assertSame('new', $data['status']);
        $this->assertSame('cash', $data['payment_method']);
        $this->assertSame('После 18:00', $data['delivery_time_note']);
        $this->assertTrue($data['can_edit']);
        $this->assertTrue($data['can_cancel_directly']);
        $this->assertFalse($data['can_request_cancellation']);
        $this->assertNull($data['cancellation_request']);
        $this->assertSame(0, $data['pending_approval_count']);
        $this->assertNull($data['payment']);
        $this->assertSame([], $data['refunds']);
        $this->assertSame([
            'merchandise_subtotal_uzs' => 62100, 'service_fee_uzs' => 5000, 'delivery_fee_uzs' => 15000,
            'total_uzs' => 82100, 'total_kind' => 'estimate',
        ], $data['totals']);
        $this->assertSame(['3.000', '2'], array_column($data['items'], 'quantity'));
        $this->assertSame([55200, 6900], array_column($data['items'], 'line_total_uzs'));
        $this->assertSame(['pending', 'pending'], array_column($data['items'], 'status'));
        $this->assertSame('45', $data['address']['apartment']);
        $this->assertStringNotContainsString('market_price', (string) json_encode($data));

        $order = Order::query()->with('items')->findOrFail((string) $data['id']);
        $this->assertSame('Aziza Karimova', $order->recipient_name_snapshot);
        $this->assertSame($this->customer->phone, $order->recipient_phone_snapshot);
        $this->assertSame($this->address->id, $order->source_address_id);
        $this->assertSame('Metro yonida', $order->landmark_snapshot);
        $this->assertSame('Domofon 45', $order->delivery_note_snapshot);
        $this->assertSame('15.00', $order->markup_percent_snapshot);
        $this->assertSame(5000, $order->service_fee_fixed_uzs_snapshot);
        $this->assertSame(15000, $order->delivery_fee_uzs_snapshot);
        $this->assertSame(60, $order->delivery_delay_threshold_minutes_snapshot);
        $tomatoLine = $order->items->firstWhere('product_id', $this->tomatoes->id);
        $this->assertNotNull($tomatoLine);
        $this->assertSame(16000, $tomatoLine->market_price_uzs_snapshot);
        $this->assertSame(18400, $tomatoLine->customer_unit_price_uzs_snapshot);
        $this->assertSame('15.00', $tomatoLine->markup_percent_snapshot);
        $this->assertSame('Qizil bo\'lsin', $tomatoLine->customer_note_snapshot);

        $history = OrderHistory::query()->where('order_id', $order->id)->sole();
        $this->assertSame(OrderStatus::New, $history->to_status);
        $this->assertNull($history->from_status);
        $this->assertSame($this->customer->id, $history->actor_user_id);

        $this->assertSame(CartStatus::Converted, $cart->fresh()?->status);
        $this->assertSame($cart->id, $order->source_cart_id);
        $new = CustomerCart::of($this->customer);
        $this->assertNotSame($cart->id, $new->id);
        $this->assertSame(0, $new->items()->count(), 'BR-CHK-008: a new, empty cart.');
    }

    public function test_a_retry_with_the_same_key_answers_the_same_order_and_creates_nothing(): void
    {
        $token = $this->token();
        $key = (string) Str::uuid();

        $first = $this->create($token, $key)->assertCreated()->json('data.id');
        $again = $this->create($token, $key)->assertCreated()->json('data.id');

        $this->assertSame($first, $again);
        $this->assertSame(1, Order::query()->count());
        $this->assertSame(1, OrderHistory::query()->count());
        $this->assertSame(2, Cart::query()->where('customer_id', $this->customer->id)->count());

        $this->create('another-token', $key)->assertStatus(409)->assertJsonPath('code', 'idempotency_key_reused');
    }

    public function test_the_same_token_under_a_new_key_cannot_order_the_cart_twice(): void
    {
        $token = $this->token();
        $this->create($token)->assertCreated();

        $this->create($token)->assertStatus(409)->assertJsonPath('code', 'checkout_snapshot_stale');
        $this->assertSame(1, Order::query()->count());
    }

    public function test_a_token_that_no_longer_matches_is_stale_and_nothing_is_created(): void
    {
        $stale = [
            'a line changed' => fn () => CartItem::query()->where('product_id', $this->tomatoes->id)->update(['quantity' => '4.000']),
            'the market price changed' => fn () => Product::query()->whereKey($this->bread->id)->update(['market_price_uzs' => 3100]),
            'the markup changed' => fn () => DB::table('business_settings')->update(['markup_percent' => '16.00']),
            'the delivery fee changed' => fn () => DB::table('business_settings')->update(['delivery_fee_uzs' => 16000]),
            'the address moved' => fn () => $this->address->forceFill(['latitude' => '41.312000'])->save(),
            'five minutes passed' => fn () => $this->travel(301)->seconds(),
        ];

        foreach ($stale as $what => $change) {
            DB::beginTransaction();
            $token = $this->token();
            $change();
            $this->create($token)->assertStatus(409)->assertJsonPath('code', 'checkout_snapshot_stale');
            $this->assertSame(0, Order::query()->count(), "{$what}: no order.");
            $this->assertSame(0, IdempotencyKey::query()->count(), "{$what}: the refused key is gone, a retry is judged again.");
            DB::rollBack();
            $this->travelTo(CarbonImmutable::parse('2026-09-27 12:00:00', 'Asia/Tashkent'));
        }
    }

    public function test_a_token_is_only_its_customers(): void
    {
        $token = $this->token();
        $other = User::factory()->customer()->create(['full_name' => 'Boshqa']);

        $this->withToken($other->createToken('t')->plainTextToken)
            ->postJson(self::ORDERS, ['checkout_token' => $token], ['Idempotency-Key' => (string) Str::uuid()])
            ->assertStatus(409)->assertJsonPath('code', 'checkout_snapshot_stale');
    }

    public function test_a_product_gone_since_the_preview_is_named_and_a_retry_is_judged_again(): void
    {
        $token = $this->token();
        Product::query()->whereKey($this->bread->id)->update(['is_active' => false]);
        $key = (string) Str::uuid();

        $this->create($token, $key)->assertStatus(409)
            ->assertJsonPath('code', 'product_unavailable')
            ->assertJsonPath('details.product_ids', [$this->bread->id]);

        Product::query()->whereKey($this->bread->id)->update(['is_active' => true]);
        $this->create($token, $key)->assertCreated();
    }

    public function test_a_retry_after_the_token_expired_still_answers_the_order(): void
    {
        $token = $this->token();
        $key = (string) Str::uuid();
        $first = $this->create($token, $key)->assertCreated()->json('data.id');

        $this->travel(CheckoutToken::TTL_SECONDS + 1)->seconds();

        $this->create($token, $key)->assertCreated()->assertJsonPath('data.id', $first);
        $this->assertSame(1, Order::query()->count());
    }

    public function test_after_an_order_the_old_lines_are_gone_and_a_new_line_lands_in_the_new_cart(): void
    {
        $oldLine = CartItem::query()->where('product_id', $this->tomatoes->id)->value('id');
        $this->create($this->token())->assertCreated();

        $this->asCustomer()->patchJson('/api/v1/customer/cart/items/'.$oldLine, ['quantity' => '5'])->assertStatus(404);
        $this->asCustomer()->deleteJson('/api/v1/customer/cart/items/'.$oldLine)->assertStatus(404);
        $cart = $this->asCustomer()->postJson('/api/v1/customer/cart/items', ['product_id' => $this->tomatoes->id, 'quantity' => '1'])
            ->assertCreated();
        $this->assertSame(CustomerCart::of($this->customer)->id, $cart->json('data.id'));
        $this->assertSame(1, $cart->json('data.item_count'));
    }

    public function test_an_address_removed_since_the_preview_makes_the_token_stale(): void
    {
        $token = $this->token();
        $this->address->forceFill(['is_active' => false])->save();

        $this->create($token)->assertStatus(409)->assertJsonPath('code', 'checkout_snapshot_stale');
        $this->assertSame(0, Order::query()->count());
    }

    public function test_staff_cannot_reach_the_customers_orders(): void
    {
        $shopper = User::factory()->role(Role::Shopper)->create();
        $asShopper = $this->withToken($shopper->createToken('t')->plainTextToken);
        $order = Order::factory()->create(['customer_id' => $this->customer->id]);

        $asShopper->getJson(self::ORDERS)->assertStatus(403);
        $asShopper->getJson(self::ORDERS.'/'.$order->id)->assertStatus(403);
        $asShopper->postJson(self::ORDERS, ['checkout_token' => 'x'], ['Idempotency-Key' => (string) Str::uuid()])->assertStatus(403);
        // The role is checked before the key: no key is still 403, not 400.
        $asShopper->postJson(self::ORDERS, ['checkout_token' => 'x'])->assertStatus(403);
    }

    public function test_the_key_is_required_after_the_session_and_the_body_is_held_to_its_shape(): void
    {
        $this->postJson(self::ORDERS, ['checkout_token' => 'x'])->assertStatus(401);
        $this->asCustomer()->postJson(self::ORDERS, ['checkout_token' => 'x'])
            ->assertStatus(400)->assertJsonPath('code', 'idempotency_key_required');
        $this->create($this->token(), 'not-a-uuid')->assertStatus(422);
        $this->asCustomer()->postJson(self::ORDERS, ['checkout_token' => 'x', 'total_uzs' => 1], ['Idempotency-Key' => (string) Str::uuid()])
            ->assertStatus(422);
    }

    public function test_the_order_keeps_its_snapshots_when_the_catalog_and_settings_change(): void
    {
        $id = $this->create($this->token())->assertCreated()->json('data.id');

        Product::query()->whereKey($this->tomatoes->id)->update(['name_ru' => 'Томаты', 'market_price_uzs' => 20000]);
        DB::table('business_settings')->update(['markup_percent' => '30.00', 'delivery_fee_uzs' => 25000, 'service_fee_fixed_uzs' => 9000]);
        $this->address->forceFill(['street' => 'Navoiy'])->save();

        $order = $this->asCustomer()->getJson(self::ORDERS.'/'.$id)->assertOk()->json('data');
        $this->assertSame(82100, $order['totals']['total_uzs'], 'BR-CORE-004.');
        $this->assertSame(18400, $order['items'][0]['customer_unit_price_uzs']);
        $this->assertSame($this->tomatoes->name_ru, $order['items'][0]['name_ru']);
        $this->assertNotSame('Navoiy', $order['address']['street']);
    }

    public function test_the_customer_lists_and_reads_only_their_own_orders(): void
    {
        $first = $this->create($this->token())->assertCreated()->json('data.id');
        $this->line($this->tomatoes, '4.000');
        $this->travel(1)->minutes();
        $second = $this->create($this->token())->assertCreated()->json('data.id');
        $foreign = Order::factory()->create();

        $list = $this->asCustomer()->getJson(self::ORDERS)->assertOk();
        $this->assertSame([$second, $first], array_column($list->json('data'), 'id'), 'Newest first.');
        $this->assertSame(
            ['id', 'order_number', 'status', 'payment_method', 'item_count', 'pending_approval_count', 'total_uzs', 'total_kind', 'created_at'],
            array_keys($list->json('data.0'))
        );
        $this->assertSame(1, $list->json('data.0.item_count'));
        $this->assertSame(2, $list->json('meta.pagination.total'));

        $this->asCustomer()->getJson(self::ORDERS.'/'.$foreign->id)->assertStatus(404)->assertJsonPath('code', 'resource_not_found');
        $this->asCustomer()->getJson(self::ORDERS.'/'.(string) Str::uuid())->assertStatus(404);
    }

    public function test_a_cancelled_order_owes_nothing_and_a_shopped_one_shows_its_final_amounts(): void
    {
        $cancelled = Order::factory()->shoppingAssigned()->cancelled()->create(['customer_id' => $this->customer->id]);
        $completed = Order::factory()->completed()->create(['customer_id' => $this->customer->id]);

        $this->asCustomer()->getJson(self::ORDERS.'/'.$cancelled->id)->assertOk()
            ->assertJsonPath('data.totals', ['merchandise_subtotal_uzs' => null, 'service_fee_uzs' => null, 'delivery_fee_uzs' => null, 'total_uzs' => null, 'total_kind' => 'none'])
            ->assertJsonPath('data.can_edit', false)
            ->assertJsonPath('data.cancellation_reason_code', 'customer_cancelled');
        $this->asCustomer()->getJson(self::ORDERS.'/'.$completed->id)->assertOk()
            ->assertJsonPath('data.totals.total_uzs', 120000)
            ->assertJsonPath('data.totals.total_kind', 'final')
            ->assertJsonPath('data.can_cancel_directly', false);
    }

    /**
     * @param  array<string, mixed>  $overrides
     */
    private function token(array $overrides = []): string
    {
        return (string) $this->asCustomer()
            ->postJson(self::PREVIEW, array_merge(['address_id' => $this->address->id, 'payment_method' => 'cash'], $overrides))
            ->assertOk()
            ->json('data.checkout_token');
    }

    private function create(string $token, ?string $key = null): TestResponse
    {
        return $this->asCustomer()->postJson(self::ORDERS, ['checkout_token' => $token], ['Idempotency-Key' => $key ?? (string) Str::uuid()]);
    }

    private function line(Product $product, string $quantity, ?string $note = null): void
    {
        CartItem::factory()->create([
            'cart_id' => CustomerCart::of($this->customer)->id,
            'product_id' => $product->id,
            'quantity' => $quantity,
            'customer_note' => $note,
        ]);
    }

    private function asCustomer(): self
    {
        return $this->withToken($this->customer->createToken('t')->plainTextToken);
    }
}
