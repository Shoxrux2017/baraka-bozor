<?php

declare(strict_types=1);

namespace Tests\Feature\Accounts;

use App\Exceptions\ApiException;
use App\Models\Cart;
use App\Models\CartItem;
use App\Models\CustomerAddress;
use App\Models\CustomerFavorite;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\Order;
use App\Models\OrderCancellationRequest;
use App\Models\OrderHistory;
use App\Models\OrderItem;
use App\Models\OrderRating;
use App\Models\PushDevice;
use App\Models\User;
use App\Modules\Accounts\Actions\EraseCustomer;
use App\Modules\Auth\Models\LoginChallenge;
use App\Modules\Auth\TestPhones;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * A Customer deletes their own account (`BR-ROLE-013`, `DL-94` item 4).
 */
final class AccountDeletionApiTest extends TestCase
{
    use RefreshDatabase;

    private const PHONE = '+998900000077';

    private const CODE = '000000';

    protected function setUp(): void
    {
        parent::setUp();

        config(['login_codes.test_phones' => [self::PHONE], 'login_codes.test_code' => self::CODE]);
        $this->app->forgetInstance(TestPhones::class);
    }

    public function test_a_customer_deletes_the_account(): void
    {
        $customer = $this->customer();
        $token = $customer->createToken('customer')->plainTextToken;
        CustomerAddress::factory()->count(2)->create(['customer_id' => $customer->id]);
        CustomerFavorite::factory()->create(['customer_id' => $customer->id]);
        PushDevice::factory()->create(['user_id' => $customer->id]);
        $activeCart = Cart::factory()->create(['customer_id' => $customer->id]);
        CartItem::factory()->create(['cart_id' => $activeCart->id, 'customer_note' => 'ring twice']);

        $completed = Order::factory()->completed()->create(['customer_id' => $customer->id, 'delivery_time_note' => 'after 18:00']);
        $line = OrderItem::factory()->create(['order_id' => $completed->id, 'customer_note_snapshot' => 'ripe ones']);
        $rating = OrderRating::factory()->create(['order_id' => $completed->id, 'stars' => 4, 'comment' => 'Fast courier']);
        $cancelled = Order::factory()->cancelled()->create(['customer_id' => $customer->id]);
        $request = OrderCancellationRequest::factory()->create(['order_id' => $cancelled->id, 'reason' => 'Changed my mind']);
        $before = $this->financials($completed) + $this->financials($cancelled);

        $this->withToken($token)->postJson('/api/v1/customer/account/deletion-code')->assertOk()->assertJsonPath('data.channel', 'test');
        $this->deleteWith($token, self::CODE)->assertNoContent();

        $this->flushHeaders();
        $this->withToken($token)->getJson('/api/v1/customer/profile')->assertStatus(401);

        $user = User::query()->findOrFail($customer->id);
        $this->assertSame(UserStatus::Deleted, $user->status);
        $this->assertNull($user->phone);
        $this->assertNull($user->full_name);
        $this->assertNull($user->last_login_at);
        $this->assertNotNull($user->deleted_at);
        $this->assertSame($customer->id, $user->deleted_by_user_id);
        $this->assertSame('uz', $user->preferred_language);

        $this->assertSame(0, CustomerAddress::query()->where('customer_id', $customer->id)->count());
        $this->assertSame(0, CustomerFavorite::query()->where('customer_id', $customer->id)->count());
        $this->assertSame(0, PushDevice::query()->where('user_id', $customer->id)->count());
        $this->assertSame(0, CartItem::query()->where('cart_id', $activeCart->id)->count());
        $this->assertSame(0, DB::table('personal_access_tokens')->where('tokenable_id', $customer->id)->count());
        $this->assertSame(0, LoginChallenge::query()->where('phone', self::PHONE)->count());

        foreach ([$completed, $cancelled] as $order) {
            $erased = Order::query()->findOrFail($order->id);
            $this->assertNotNull($erased->customer_erased_at);
            $this->assertNull($erased->source_address_id);

            foreach ($this->personalColumns() as $column) {
                $this->assertNull($erased->getAttribute($column), $column);
            }
        }

        $this->assertSame($before, $this->financials($completed) + $this->financials($cancelled));
        $this->assertNull(OrderItem::query()->findOrFail($line->id)->customer_note_snapshot);
        $this->assertNull(OrderRating::query()->findOrFail($rating->id)->comment);
        $this->assertSame(4, OrderRating::query()->findOrFail($rating->id)->stars);
        $this->assertNull(OrderCancellationRequest::query()->findOrFail($request->id)->reason);
    }

    public function test_the_erasure_strips_history_notes_and_keeps_history_events(): void
    {
        $customer = $this->customer();
        $order = Order::factory()->completed()->create(['customer_id' => $customer->id]);
        $productId = (string) Str::uuid();
        $lineId = (string) Str::uuid();

        $edit = $this->history($order, OrderHistoryEvent::Edited, $customer, [
            'added' => [['order_item_id' => $lineId, 'product_id' => $productId, 'quantity' => '2.000', 'customer_note' => 'a', 'substitution_policy' => 'allow_similar']],
            'removed' => [['order_item_id' => $lineId, 'product_id' => $productId, 'quantity' => '1.000', 'customer_note' => 'b']],
            'changed' => [['order_item_id' => $lineId, 'product_id' => $productId, 'before' => ['quantity' => '1.000', 'customer_note' => 'c'], 'after' => ['quantity' => '3.000', 'customer_note' => 'd']]],
            'delivery_time_note' => ['before' => 'morning', 'after' => 'evening'],
        ], 'because');
        $assigned = $this->history($order, OrderHistoryEvent::Edited, null, ['assignment_id' => 'x']);
        $cancelNote = $this->history($order, OrderHistoryEvent::Edited, $customer, ['request_id' => 'r'], 'private reason');

        $this->eraseThroughApi($customer);

        $details = OrderHistory::query()->findOrFail($edit->id)->details;
        $this->assertSame($lineId, $details['added'][0]['order_item_id']);
        $this->assertSame('2.000', $details['added'][0]['quantity']);
        $this->assertSame('allow_similar', $details['added'][0]['substitution_policy']);
        $this->assertSame('1.000', $details['removed'][0]['quantity']);
        $this->assertSame('3.000', $details['changed'][0]['after']['quantity']);
        $this->assertSame('1.000', $details['changed'][0]['before']['quantity']);
        // The keys stay (the panel reads them), their values go.
        foreach ([$details['added'][0], $details['removed'][0], $details['changed'][0]['before'], $details['changed'][0]['after']] as $line) {
            $this->assertArrayHasKey('customer_note', $line);
            $this->assertNull($line['customer_note']);
        }
        $this->assertEquals(['before' => null, 'after' => null], $details['delivery_time_note']);
        $encoded = json_encode($details, JSON_THROW_ON_ERROR);
        foreach (['morning', 'evening', '"a"', '"b"', '"c"', '"d"'] as $text) {
            $this->assertStringNotContainsString($text, $encoded);
        }

        $this->assertNull(OrderHistory::query()->findOrFail($edit->id)->note);
        $this->assertNull(OrderHistory::query()->findOrFail($cancelNote->id)->note);
        $this->assertSame(['assignment_id' => 'x'], OrderHistory::query()->findOrFail($assigned->id)->details);
        $this->assertSame($customer->id, OrderHistory::query()->findOrFail($edit->id)->actor_user_id);
    }

    public function test_the_stored_answers_of_the_account_are_deleted(): void
    {
        $customer = $this->customer();
        $other = $this->customer('+998900000078');
        foreach ([$customer, $other] as $user) {
            DB::table('idempotency_keys')->insert([
                'id' => (string) Str::uuid(),
                'actor_user_id' => $user->id,
                'operation' => 'orders.reorder',
                'idempotency_key' => (string) Str::uuid(),
                'request_hash' => str_repeat('a', 64),
                'state' => 'completed',
                'attempt_token' => (string) Str::uuid(),
                'lease_expires_at' => now(),
                'response' => json_encode(['x' => 1]),
                'created_at' => now(),
                'completed_at' => now(),
            ]);
        }

        $this->eraseThroughApi($customer);

        $this->assertSame(0, DB::table('idempotency_keys')->where('actor_user_id', $customer->id)->count());
        $this->assertSame(1, DB::table('idempotency_keys')->where('actor_user_id', $other->id)->count());
    }

    public function test_another_customer_is_untouched(): void
    {
        $customer = $this->customer();
        $other = $this->customer('+998900000078');
        CustomerAddress::factory()->create(['customer_id' => $customer->id]);
        $address = CustomerAddress::factory()->create(['customer_id' => $other->id]);
        $order = Order::factory()->completed()->create(['customer_id' => $other->id, 'delivery_time_note' => 'evening']);
        OrderRating::factory()->create(['order_id' => $order->id, 'comment' => 'ok']);
        $snapshot = fn (): string => json_encode([
            User::query()->findOrFail($other->id)->getAttributes(),
            CustomerAddress::query()->findOrFail($address->id)->getAttributes(),
            Order::query()->findOrFail($order->id)->getAttributes(),
            DB::table('order_ratings')->where('order_id', $order->id)->get()->all(),
        ], JSON_THROW_ON_ERROR);
        $before = $snapshot();

        $this->eraseThroughApi($customer);

        $this->assertSame($before, $snapshot());
    }

    public function test_an_unfinished_order_blocks_deletion(): void
    {
        $customer = $this->customer();
        $token = $customer->createToken('customer')->plainTextToken;
        $order = Order::factory()->shopping()->create(['customer_id' => $customer->id]);

        $this->withToken($token)->postJson('/api/v1/customer/account/deletion-code')
            ->assertStatus(409)
            ->assertJsonPath('code', 'account_has_unfinished_orders')
            ->assertJsonPath('details.order_id', $order->id)
            ->assertJsonPath('details.order_number', $order->refresh()->order_number);
        $this->assertSame(0, LoginChallenge::query()->count());

        LoginChallenge::query()->forceCreate([
            'phone' => self::PHONE, 'purpose' => LoginChallenge::PURPOSE_ACCOUNT_DELETION, 'code_hash' => bcrypt(self::CODE),
            'failed_attempts' => 0, 'channel' => 'test', 'expires_at' => now()->addMinutes(5), 'created_at' => now(),
        ]);

        $this->deleteWith($token, self::CODE)->assertStatus(409)->assertJsonPath('code', 'account_has_unfinished_orders');
        $this->assertNull(LoginChallenge::query()->sole()->consumed_at);
        $this->assertSame(UserStatus::Active, User::query()->findOrFail($customer->id)->status);
    }

    public function test_the_erasure_itself_refuses_an_unfinished_order_and_changes_nothing(): void
    {
        $customer = $this->customer();
        Order::factory()->new()->create(['customer_id' => $customer->id]);
        $addresses = CustomerAddress::query()->where('customer_id', $customer->id)->count();

        try {
            $this->app->make(EraseCustomer::class)->erase($customer, $customer);
            $this->fail('The erasure must refuse.');
        } catch (ApiException $refusal) {
            $this->assertSame('account_has_unfinished_orders', $refusal->apiCode());
        }

        $this->assertSame(UserStatus::Active, User::query()->findOrFail($customer->id)->status);
        $this->assertSame($addresses, CustomerAddress::query()->where('customer_id', $customer->id)->count());
    }

    public function test_wrong_codes_answer_422_then_lock(): void
    {
        $customer = $this->customer();
        $token = $customer->createToken('customer')->plainTextToken;
        $this->withToken($token)->postJson('/api/v1/customer/account/deletion-code')->assertOk();

        $this->deleteWith($token, '111111')->assertStatus(422)->assertJsonPath('code', 'code_invalid');
        $this->deleteWith($token, '111111')->assertStatus(422)->assertJsonPath('code', 'code_invalid');
        $this->deleteWith($token, '111111')->assertStatus(429)->assertJsonPath('code', 'code_locked')->assertHeader('Retry-After');

        $this->assertSame(UserStatus::Active, User::query()->findOrFail($customer->id)->status);
        $this->flushHeaders();
        $this->postJson('/api/v1/auth/customer/code/request', ['phone' => self::PHONE])->assertStatus(429)->assertJsonPath('code', 'code_locked');
    }

    public function test_an_expired_code_and_an_exhausted_code_answer_422(): void
    {
        $customer = $this->customer();
        $token = $customer->createToken('customer')->plainTextToken;
        $challenge = fn (array $state) => LoginChallenge::query()->forceCreate($state + [
            'phone' => self::PHONE, 'purpose' => LoginChallenge::PURPOSE_ACCOUNT_DELETION, 'code_hash' => bcrypt(self::CODE),
            'failed_attempts' => 0, 'channel' => 'test', 'expires_at' => now()->addMinutes(5), 'created_at' => now(),
        ]);

        $challenge(['expires_at' => now()->subMinute()]);
        $this->deleteWith($token, self::CODE)->assertStatus(422)->assertJsonPath('code', 'code_expired');

        LoginChallenge::query()->delete();
        $challenge(['failed_attempts' => 3]);
        $this->deleteWith($token, self::CODE)->assertStatus(422)->assertJsonPath('code', 'code_attempts_exhausted');

        $this->assertSame(UserStatus::Active, User::query()->findOrFail($customer->id)->status);
    }

    public function test_a_sign_in_code_never_deletes_an_account(): void
    {
        $customer = $this->customer();
        $token = $customer->createToken('customer')->plainTextToken;
        $this->postJson('/api/v1/auth/customer/code/request', ['phone' => self::PHONE])->assertOk();

        $this->deleteWith($token, self::CODE)->assertStatus(422)->assertJsonPath('code', 'code_invalid');
        $this->assertSame(UserStatus::Active, User::query()->findOrFail($customer->id)->status);
    }

    public function test_the_phone_signs_in_again_as_a_new_customer(): void
    {
        $customer = $this->customer();
        CustomerAddress::factory()->create(['customer_id' => $customer->id]);
        Order::factory()->completed()->create(['customer_id' => $customer->id]);
        $this->eraseThroughApi($customer);

        $this->flushHeaders();
        $this->postJson('/api/v1/auth/customer/code/request', ['phone' => self::PHONE])->assertOk();
        $login = $this->postJson('/api/v1/auth/customer/code/verify', ['phone' => self::PHONE, 'code' => self::CODE])->assertOk();

        $this->assertNotSame($customer->id, $login->json('data.user.id'));
        $token = (string) $login->json('data.token');
        $this->flushHeaders();
        $this->withToken($token)->getJson('/api/v1/customer/addresses')->assertOk()->assertJsonCount(0, 'data');
        $this->flushHeaders();
        $this->withToken($token)->getJson('/api/v1/customer/orders')->assertOk()->assertJsonCount(0, 'data');
        $this->assertSame(1, Order::query()->where('customer_id', $customer->id)->count());
    }

    public function test_a_blocked_customer_still_cannot_escape_the_block(): void
    {
        User::factory()->customer()->blocked()->create(['phone' => self::PHONE]);

        $this->postJson('/api/v1/auth/customer/code/request', ['phone' => self::PHONE])->assertOk();
        $this->postJson('/api/v1/auth/customer/code/verify', ['phone' => self::PHONE, 'code' => self::CODE])
            ->assertStatus(401)
            ->assertJsonPath('code', 'account_blocked');
    }

    public function test_a_deleted_account_cannot_act_even_with_a_token(): void
    {
        $customer = $this->customer();
        $token = $customer->createToken('customer')->plainTextToken;
        $customer->forceFill(['status' => UserStatus::Deleted, 'phone' => null, 'deleted_at' => now()])->save();

        $this->withToken($token)->getJson('/api/v1/customer/profile')->assertStatus(401);
    }

    public function test_only_customers_and_no_body_fields(): void
    {
        foreach ([Role::Shopper, Role::Courier, Role::Operator, Role::Admin, Role::Manager] as $role) {
            $staff = User::factory()->role($role)->create();
            $token = $staff->createToken('staff')->plainTextToken;

            $this->flushHeaders();
            $this->withToken($token)->postJson('/api/v1/customer/account/deletion-code')->assertStatus(403);
            $this->flushHeaders();
            $this->withToken($token)->postJson('/api/v1/customer/account/delete', ['code' => self::CODE])->assertStatus(403);
        }

        $customer = $this->customer();
        $token = $customer->createToken('customer')->plainTextToken;

        $this->flushHeaders();
        $this->withToken($token)->postJson('/api/v1/customer/account/deletion-code', ['phone' => self::PHONE])->assertStatus(422);
        $this->flushHeaders();
        $this->withToken($token)->postJson('/api/v1/customer/account/delete', ['code' => self::CODE, 'extra' => 1])->assertStatus(422);
        $this->flushHeaders();
        $this->withToken($token)->postJson('/api/v1/customer/account/delete', ['code' => '12345'])->assertStatus(422);
        $this->assertSame(UserStatus::Active, User::query()->findOrFail($customer->id)->status);
    }

    private function customer(string $phone = self::PHONE): User
    {
        return User::factory()->customer()->create(['phone' => $phone, 'full_name' => 'Aziza Karimova']);
    }

    private function eraseThroughApi(User $customer): void
    {
        $token = $customer->createToken('customer')->plainTextToken;
        $this->flushHeaders();
        $this->withToken($token)->postJson('/api/v1/customer/account/deletion-code')->assertOk();
        $this->deleteWith($token, self::CODE)->assertNoContent();
    }

    private function deleteWith(string $token, string $code): TestResponse
    {
        $this->flushHeaders();

        return $this->withToken($token)->postJson('/api/v1/customer/account/delete', ['code' => $code]);
    }

    /**
     * @return list<string>
     */
    private function personalColumns(): array
    {
        return [
            'recipient_name_snapshot', 'recipient_phone_snapshot', 'latitude_snapshot', 'longitude_snapshot',
            'street_snapshot', 'house_snapshot', 'apartment_snapshot', 'landmark_snapshot',
            'delivery_note_snapshot', 'delivery_time_note',
        ];
    }

    /**
     * What erasure must never change.
     *
     * @return array<string, array<string, mixed>>
     */
    private function financials(Order $order): array
    {
        $row = (array) DB::table('orders')->where('id', $order->id)->first();

        return [$order->id => [
            'status' => $row['status'],
            'totals' => [$row['final_merchandise_subtotal_uzs'], $row['final_service_fee_uzs'], $row['final_total_uzs'], $row['delivery_fee_uzs_snapshot']],
            'payments' => DB::table('payments')->where('order_id', $order->id)->get()->map(fn ($p) => (array) $p)->all(),
            'history' => DB::table('order_history')->where('order_id', $order->id)->count(),
            'items' => DB::table('order_items')->where('order_id', $order->id)->pluck('ordered_quantity', 'id')->all(),
        ]];
    }

    /**
     * @param  array<string, mixed>  $details
     */
    private function history(Order $order, OrderHistoryEvent $event, ?User $actor, array $details, ?string $note = null): OrderHistory
    {
        $history = new OrderHistory;
        $history->forceFill([
            'order_id' => $order->id,
            'event_type' => $event,
            'actor_type' => $actor === null ? HistoryActorType::System : HistoryActorType::User,
            'actor_user_id' => $actor?->id,
            'note' => $note,
            'details' => $details,
        ])->save();

        return $history;
    }
}
