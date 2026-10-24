<?php

declare(strict_types=1);

namespace Tests\Feature\Notifications;

use App\Models\BusinessSettings;
use App\Models\CartItem;
use App\Models\CustomerAddress;
use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\PushDevice;
use App\Models\User;
use App\Modules\Notifications\Push\FakePushSender;
use App\Modules\Notifications\Push\PushMessage;
use App\Modules\Orders\CustomerCart;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * The pushes of the order's main path (`DL-104` (10)): creation, the two
 * assignments, the completion of shopping, a price correction, departure and
 * delivery. Every recipient holds one active device.
 */
final class OrderPathNotificationsTest extends TestCase
{
    use RefreshDatabase;

    private FakePushSender $push;

    private int $forgotten = 0;

    protected function setUp(): void
    {
        parent::setUp();

        $this->push = $this->app->make(FakePushSender::class);
    }

    private function withDevice(Role $role): User
    {
        $user = User::factory()->role($role)->create();
        PushDevice::factory()->create(['user_id' => $user->id]);

        return $user;
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }

    private function tokenOf(User $user): string
    {
        return (string) PushDevice::query()->where('user_id', $user->id)->value('push_token');
    }

    /**
     * What was pushed, as `event => [tokens]`.
     *
     * @return array<string, list<string>>
     */
    private function pushed(): array
    {
        $pushed = [];
        foreach ($this->sent() as $sent) {
            $pushed[$sent['message']->data['event']][] = $sent['token'];
        }

        return $pushed;
    }

    /** Pushes sent before this point are no longer counted. */
    private function forgetPushes(): void
    {
        $this->forgotten = count($this->push->sent());
    }

    /**
     * @return list<array{token: string, message: PushMessage}>
     */
    private function sent(): array
    {
        return array_slice($this->push->sent(), $this->forgotten);
    }

    private function assertOnlyPushed(string $event, User $recipient): void
    {
        $this->assertSame([$event => [$this->tokenOf($recipient)]], $this->pushed());
    }

    private function prepareCheckout(User $customer): string
    {
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
        CartItem::factory()->create([
            'cart_id' => CustomerCart::of($customer)->id,
            'product_id' => Product::factory()->create(['market_price_uzs' => 16000])->id,
            'quantity' => '3.000',
        ]);
        $address = CustomerAddress::factory()->create(['customer_id' => $customer->id]);

        return (string) $this->as($customer)
            ->postJson('/api/v1/customer/checkout/preview', ['address_id' => $address->id, 'payment_method' => 'cash'])
            ->assertOk()
            ->json('data.checkout_token');
    }

    private function createOrder(User $customer, string $checkoutToken, string $idempotencyKey): TestResponse
    {
        return $this->as($customer)->postJson('/api/v1/customer/orders', ['checkout_token' => $checkoutToken], ['Idempotency-Key' => $idempotencyKey]);
    }

    private function assignShopper(Order $order, User $shopper, User $by, string $method = 'post', ?string $replaces = null): TestResponse
    {
        $body = ['shopper_id' => $shopper->id];
        if ($method === 'put') {
            $body['replaces_assignment_id'] = $replaces;
        }

        return $this->as($by)->json(strtoupper($method), "/api/v1/operations/orders/{$order->id}/shopper-assignment", $body);
    }

    private function assignCourier(Order $order, User $courier, User $by): TestResponse
    {
        return $this->as($by)->postJson("/api/v1/operations/orders/{$order->id}/courier-assignment", ['courier_id' => $courier->id]);
    }

    private function shoppedOrder(User $shopper, User $customer, bool $online = false): Order
    {
        $factory = $online ? Order::factory()->online()->shopping() : Order::factory()->shopping();
        $order = $factory->create(['customer_id' => $customer->id]);
        $order->shopperAssignments()->update(['shopper_id' => $shopper->id]);

        return $order;
    }

    private function buy(Order $order, User $shopper): OrderItem
    {
        $line = OrderItem::factory()->for($order)->create();
        $this->as($shopper)->withHeader('Idempotency-Key', (string) Str::uuid())
            ->postJson("/api/v1/shopper/orders/{$order->id}/items/{$line->id}/purchase", ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 17000])
            ->assertOk();

        return $line;
    }

    private function complete(Order $order, User $shopper, ?string $key = null): TestResponse
    {
        return $this->as($shopper)->withHeader('Idempotency-Key', $key ?? (string) Str::uuid())
            ->postJson("/api/v1/shopper/orders/{$order->id}/complete");
    }

    private function correct(OrderItem $line, int $price, User $admin): TestResponse
    {
        return $this->as($admin)->postJson(
            "/api/v1/admin/orders/{$line->order_id}/items/{$line->id}/price-correction",
            ['actual_market_price_uzs' => $price, 'reason' => 'Opechatka'],
        );
    }

    private function deliver(Order $order, User $courier, string $key): TestResponse
    {
        return $this->as($courier)->withHeader('Idempotency-Key', $key)
            ->postJson("/api/v1/courier/orders/{$order->id}/delivered", ['cash_received_uzs' => $order->final_total_uzs]);
    }

    private function assertBodyHasAmount(int $uzs): void
    {
        $this->assertStringContainsString(number_format($uzs, 0, '.', mb_chr(0xA0)), $this->sent()[0]['message']->body);
    }

    public function test_a_created_order_tells_its_customer_that_it_is_accepted(): void
    {
        $customer = $this->withDevice(Role::Customer);
        $operator = $this->withDevice(Role::Operator);
        $token = $this->prepareCheckout($customer);

        $this->createOrder($customer, $token, (string) Str::uuid())->assertCreated();

        $this->assertOnlyPushed('order_accepted', $customer);
        $order = Order::query()->sole();
        $this->assertNotSame($this->tokenOf($operator), $this->sent()[0]['token']);
        $this->assertSame(['event' => 'order_accepted', 'order_id' => $order->id], $this->sent()[0]['message']->data);
        $this->assertStringContainsString((string) $order->order_number, $this->sent()[0]['message']->body);
    }

    public function test_a_replayed_order_creation_sends_no_second_push(): void
    {
        $customer = $this->withDevice(Role::Customer);
        $token = $this->prepareCheckout($customer);
        $key = (string) Str::uuid();

        $this->createOrder($customer, $token, $key)->assertCreated();
        $this->createOrder($customer, $token, $key)->assertSuccessful();

        $this->assertSame(1, Order::query()->count());
        $this->assertOnlyPushed('order_accepted', $customer);
    }

    public function test_an_assigned_shopper_is_told_and_nobody_else(): void
    {
        $operator = $this->withDevice(Role::Operator);
        $shopper = $this->withDevice(Role::Shopper);
        $customer = $this->withDevice(Role::Customer);
        $order = Order::factory()->create(['customer_id' => $customer->id]);

        $this->assignShopper($order, $shopper, $operator)->assertOk();

        $this->assertOnlyPushed('shopping_assigned', $shopper);
    }

    public function test_assigning_the_same_shopper_again_sends_nothing_new(): void
    {
        $operator = $this->withDevice(Role::Operator);
        $shopper = $this->withDevice(Role::Shopper);
        $order = Order::factory()->create();

        $this->assignShopper($order, $shopper, $operator)->assertOk();
        $this->assignShopper($order, $shopper, $operator)->assertOk();

        $this->assertOnlyPushed('shopping_assigned', $shopper);
    }

    public function test_a_reassigned_shopper_is_not_told_and_the_new_one_is(): void
    {
        $operator = $this->withDevice(Role::Operator);
        $first = $this->withDevice(Role::Shopper);
        $second = $this->withDevice(Role::Shopper);
        $order = Order::factory()->create();
        $this->assignShopper($order, $first, $operator)->assertOk();
        $this->forgetPushes();

        $this->assignShopper($order, $second, $operator, 'put', $order->shopperAssignments()->sole()->id)->assertOk();

        $this->assertOnlyPushed('shopping_assigned', $second);
    }

    public function test_an_assigned_courier_is_told_and_a_repeat_sends_nothing_new(): void
    {
        $operator = $this->withDevice(Role::Operator);
        $courier = $this->withDevice(Role::Courier);
        $customer = $this->withDevice(Role::Customer);
        $order = Order::factory()->readyForDelivery()->create(['customer_id' => $customer->id]);

        $this->assignCourier($order, $courier, $operator)->assertOk();
        $this->assignCourier($order, $courier, $operator)->assertOk();

        $this->assertOnlyPushed('delivery_assigned', $courier);
    }

    public function test_a_completed_cash_shopping_tells_the_customer_the_final_total(): void
    {
        $shopper = $this->withDevice(Role::Shopper);
        $customer = $this->withDevice(Role::Customer);
        $order = $this->shoppedOrder($shopper, $customer);
        $this->buy($order, $shopper);

        $this->complete($order, $shopper)->assertOk();

        $this->assertOnlyPushed('shopping_completed', $customer);
        $this->assertBodyHasAmount((int) $order->fresh()->final_total_uzs);
    }

    public function test_a_replayed_completion_sends_no_second_push(): void
    {
        $shopper = $this->withDevice(Role::Shopper);
        $customer = $this->withDevice(Role::Customer);
        $order = $this->shoppedOrder($shopper, $customer);
        $this->buy($order, $shopper);
        $key = (string) Str::uuid();

        $this->complete($order, $shopper, $key)->assertOk();
        $this->complete($order, $shopper, $key)->assertOk();

        $this->assertOnlyPushed('shopping_completed', $customer);
    }

    public function test_an_online_order_completion_sends_nothing(): void
    {
        $shopper = $this->withDevice(Role::Shopper);
        $customer = $this->withDevice(Role::Customer);
        $order = $this->shoppedOrder($shopper, $customer, online: true);
        $this->buy($order, $shopper);

        $this->complete($order, $shopper)->assertStatus(409);

        $this->assertSame([], $this->sent());
    }

    public function test_a_price_correction_that_changes_the_total_sends_the_new_amount(): void
    {
        $shopper = $this->withDevice(Role::Shopper);
        $customer = $this->withDevice(Role::Customer);
        $admin = $this->withDevice(Role::Admin);
        $order = $this->shoppedOrder($shopper, $customer);
        $line = $this->buy($order, $shopper);
        $this->complete($order, $shopper)->assertOk();
        $before = (int) $order->fresh()->final_total_uzs;
        $this->forgetPushes();

        $this->correct($line, 16500, $admin)->assertOk();

        $after = (int) $order->fresh()->final_total_uzs;
        $this->assertNotSame($before, $after);
        $this->assertOnlyPushed('shopping_completed', $customer);
        $this->assertBodyHasAmount($after);
    }

    public function test_a_correction_to_the_same_price_sends_nothing(): void
    {
        $shopper = $this->withDevice(Role::Shopper);
        $customer = $this->withDevice(Role::Customer);
        $admin = $this->withDevice(Role::Admin);
        $order = $this->shoppedOrder($shopper, $customer);
        $line = $this->buy($order, $shopper);
        $this->complete($order, $shopper)->assertOk();
        $this->correct($line, 16500, $admin)->assertOk();
        $this->forgetPushes();

        $this->correct($line, 16500, $admin)->assertOk();

        $this->assertSame([], $this->sent());
    }

    public function test_a_correction_before_completion_sends_nothing(): void
    {
        $shopper = $this->withDevice(Role::Shopper);
        $customer = $this->withDevice(Role::Customer);
        $admin = $this->withDevice(Role::Admin);
        $order = $this->shoppedOrder($shopper, $customer);
        $order->forceFill(['final_total_uzs' => null])->save();
        $line = $this->buy($order, $shopper);

        $this->correct($line, 16500, $admin)->assertOk();

        $this->assertSame([], $this->sent());
    }

    public function test_a_departure_tells_the_customer_and_a_repeat_sends_nothing(): void
    {
        $courier = $this->withDevice(Role::Courier);
        $customer = $this->withDevice(Role::Customer);
        $order = Order::factory()->deliveryAssigned()->create(['customer_id' => $customer->id]);
        $order->courierAssignments()->update(['courier_id' => $courier->id, 'accepted_at' => now()]);

        $this->as($courier)->postJson("/api/v1/courier/orders/{$order->id}/start")->assertOk();
        $this->as($courier)->postJson("/api/v1/courier/orders/{$order->id}/start")->assertOk();

        $this->assertOnlyPushed('courier_started', $customer);
    }

    public function test_a_replayed_delivery_sends_no_second_push(): void
    {
        $courier = $this->withDevice(Role::Courier);
        $customer = $this->withDevice(Role::Customer);
        $order = Order::factory()->onTheWay()->create(['customer_id' => $customer->id]);
        $order->courierAssignments()->update(['courier_id' => $courier->id]);
        $key = (string) Str::uuid();

        $this->deliver($order, $courier, $key)->assertOk();
        $this->assertOnlyPushed('order_delivered', $customer);

        $this->deliver($order, $courier, $key)->assertOk();
        $this->deliver($order, $courier, (string) Str::uuid())->assertOk();
        $this->assertOnlyPushed('order_delivered', $customer);
    }
}
