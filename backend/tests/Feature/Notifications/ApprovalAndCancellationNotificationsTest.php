<?php

declare(strict_types=1);

namespace Tests\Feature\Notifications;

use App\Models\CustomerApproval;
use App\Models\Enums\NotificationDeliveryStatus;
use App\Models\Enums\Role;
use App\Models\Enums\SubstitutionPolicy;
use App\Models\Enums\UserStatus;
use App\Models\NotificationDelivery;
use App\Models\Order;
use App\Models\OrderCancellationRequest;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\PushDevice;
use App\Models\User;
use App\Modules\Auth\TestPhones;
use App\Modules\Notifications\Push\FakePushSender;
use App\Modules\Notifications\Push\PushMessage;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * The pushes of questions, answers and the paths that cancel an order
 * (`DL-104` (10)). Every recipient holds one active device.
 */
final class ApprovalAndCancellationNotificationsTest extends TestCase
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
        $this->flushHeaders();

        return $this->withToken($user->createToken('t')->plainTextToken);
    }

    private function tokenOf(User $user): string
    {
        return (string) PushDevice::query()->where('user_id', $user->id)->value('push_token');
    }

    /**
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

    /**
     * @param  array<string, User>  $expected  event => its one recipient
     */
    private function assertPushed(array $expected): void
    {
        $tokens = [];
        foreach ($expected as $event => $recipient) {
            $tokens[$event] = [$this->tokenOf($recipient)];
        }

        $this->assertEquals($tokens, $this->pushed());
    }

    /** An order being shopped by the Shopper for the Customer. */
    private function shopped(User $shopper, User $customer): Order
    {
        $order = Order::factory()->shopping()->create(['customer_id' => $customer->id]);
        $order->shopperAssignments()->update(['shopper_id' => $shopper->id]);

        return $order;
    }

    private function waiting(Order $order): CustomerApproval
    {
        /** @var CustomerApproval $approval */
        $approval = CustomerApproval::factory()->create([
            'order_item_id' => OrderItem::factory()->for($order)->awaitingCustomer()->create()->id,
        ]);

        return $approval;
    }

    private function decide(CustomerApproval $approval, User $customer, string $decision, ?string $key = null): TestResponse
    {
        return $this->as($customer)->withHeader('Idempotency-Key', $key ?? (string) Str::uuid())
            ->postJson("/api/v1/customer/approvals/{$approval->id}/decision", ['decision' => $decision]);
    }

    private function cancelByCustomer(Order $order, User $customer, ?string $reason = null): TestResponse
    {
        return $this->as($customer)->withHeader('Idempotency-Key', (string) Str::uuid())
            ->postJson("/api/v1/customer/orders/{$order->id}/cancel", $reason === null ? [] : ['reason' => $reason]);
    }

    private function decideRequest(OrderCancellationRequest $request, User $operator, string $decision): TestResponse
    {
        return $this->as($operator)->postJson("/api/v1/operations/cancellation-requests/{$request->id}/decision", ['decision' => $decision]);
    }

    private function ask(User $shopper, OrderItem $line, string $action, array $body): TestResponse
    {
        return $this->as($shopper)->postJson("/api/v1/shopper/orders/{$line->order_id}/items/{$line->id}/{$action}", $body);
    }

    public function test_a_price_question_tells_the_customer_with_the_approval_id(): void
    {
        $shopper = $this->withDevice(Role::Shopper);
        $customer = $this->withDevice(Role::Customer);
        $line = OrderItem::factory()->for($this->shopped($shopper, $customer))->create();

        $this->ask($shopper, $line, 'price-approval', ['actual_market_price_uzs' => 20000])->assertOk();

        $this->assertPushed(['approval_required' => $customer]);
        $this->assertSame(CustomerApproval::query()->sole()->id, NotificationDelivery::query()->sole()->approval_id);
    }

    public function test_a_quantity_question_tells_the_customer(): void
    {
        $shopper = $this->withDevice(Role::Shopper);
        $customer = $this->withDevice(Role::Customer);
        $line = OrderItem::factory()->for($this->shopped($shopper, $customer))->create(['ordered_quantity' => '3.000']);

        $this->ask($shopper, $line, 'reduced-quantity-approval', ['proposed_quantity' => '1.000'])->assertOk();

        $this->assertPushed(['approval_required' => $customer]);
    }

    public function test_a_replacement_question_tells_the_customer(): void
    {
        $shopper = $this->withDevice(Role::Shopper);
        $customer = $this->withDevice(Role::Customer);
        $line = OrderItem::factory()->for($this->shopped($shopper, $customer))->create(['substitution_policy_snapshot' => SubstitutionPolicy::ContactBefore]);
        $replacement = Product::factory()->create(['unit_code' => $line->unit_code_snapshot, 'market_price_uzs' => 18000]);

        $this->ask($shopper, $line, 'substitution', ['replacement_product_id' => $replacement->id, 'actual_market_price_uzs' => 18400])->assertOk();

        $this->assertPushed(['approval_required' => $customer]);
    }

    public function test_an_approval_tells_the_current_shopper_and_a_repeat_sends_nothing_again(): void
    {
        $shopper = $this->withDevice(Role::Shopper);
        $customer = $this->withDevice(Role::Customer);
        $approval = $this->waiting($this->shopped($shopper, $customer));
        $key = (string) Str::uuid();

        $this->decide($approval, $customer, 'approve', $key)->assertOk();
        $this->decide($approval, $customer, 'approve', $key)->assertOk();

        $this->assertPushed(['approval_answered' => $shopper]);
        $this->assertSame($approval->id, NotificationDelivery::query()->sole()->approval_id);
    }

    public function test_a_rejection_that_leaves_lines_to_buy_tells_the_current_shopper(): void
    {
        $shopper = $this->withDevice(Role::Shopper);
        $customer = $this->withDevice(Role::Customer);
        $order = $this->shopped($shopper, $customer);
        OrderItem::factory()->for($order)->create();
        $approval = $this->waiting($order);

        $this->decide($approval, $customer, 'reject')->assertOk();

        $this->assertPushed(['approval_answered' => $shopper]);
    }

    public function test_an_answer_that_empties_the_order_tells_the_shopper_it_is_cancelled_instead_of_the_answer(): void
    {
        $shopper = $this->withDevice(Role::Shopper);
        $customer = $this->withDevice(Role::Customer);
        $approval = $this->waiting($this->shopped($shopper, $customer));

        $this->decide($approval, $customer, 'reject')->assertOk();

        $this->assertPushed(['shopping_order_cancelled' => $shopper]);
    }

    public function test_the_operators_removal_of_the_last_expired_line_tells_the_customer_and_the_shopper(): void
    {
        $shopper = $this->withDevice(Role::Shopper);
        $customer = $this->withDevice(Role::Customer);
        $operator = $this->withDevice(Role::Operator);
        $order = $this->shopped($shopper, $customer);
        $approval = CustomerApproval::factory()->expired()->create([
            'order_item_id' => OrderItem::factory()->for($order)->awaitingCustomer()->create()->id,
        ]);

        $this->as($operator)->postJson("/api/v1/operations/approvals/{$approval->id}/resolve-expired", ['resolution' => 'remove_item'])->assertOk();

        $this->assertPushed(['order_cancelled' => $customer, 'shopping_order_cancelled' => $shopper]);
    }

    public function test_the_operators_removal_of_an_expired_line_that_leaves_others_sends_nothing(): void
    {
        $shopper = $this->withDevice(Role::Shopper);
        $customer = $this->withDevice(Role::Customer);
        $operator = $this->withDevice(Role::Operator);
        $order = $this->shopped($shopper, $customer);
        OrderItem::factory()->for($order)->create();
        $approval = CustomerApproval::factory()->expired()->create([
            'order_item_id' => OrderItem::factory()->for($order)->awaitingCustomer()->create()->id,
        ]);

        $this->as($operator)->postJson("/api/v1/operations/approvals/{$approval->id}/resolve-expired", ['resolution' => 'remove_item'])->assertOk();

        $this->assertSame([], $this->sent());
    }

    public function test_a_question_resolved_by_expiry_alone_tells_nobody(): void
    {
        $shopper = $this->withDevice(Role::Shopper);
        $customer = $this->withDevice(Role::Customer);
        CustomerApproval::factory()->create([
            'order_item_id' => OrderItem::factory()->for($this->shopped($shopper, $customer))->awaitingCustomer()->create()->id,
            'attention_at' => now()->subHour(),
            'expires_at' => now()->subMinute(),
        ]);

        $this->artisan('approvals:expire')->assertSuccessful();

        $this->assertSame([], $this->sent());
    }

    public function test_a_shoppers_unavailable_line_that_empties_the_order_tells_only_the_customer(): void
    {
        $shopper = $this->withDevice(Role::Shopper);
        $customer = $this->withDevice(Role::Customer);
        $order = $this->shopped($shopper, $customer);
        $line = OrderItem::factory()->for($order)->create();

        $this->as($shopper)->postJson("/api/v1/shopper/orders/{$order->id}/items/{$line->id}/unavailable")->assertOk();

        $this->assertPushed(['order_cancelled' => $customer]);
    }

    public function test_an_unavailable_line_that_leaves_others_sends_nothing(): void
    {
        $shopper = $this->withDevice(Role::Shopper);
        $customer = $this->withDevice(Role::Customer);
        $order = $this->shopped($shopper, $customer);
        $line = OrderItem::factory()->for($order)->create();
        OrderItem::factory()->for($order)->create();

        $this->as($shopper)->postJson("/api/v1/shopper/orders/{$order->id}/items/{$line->id}/unavailable")->assertOk();

        $this->assertSame([], $this->sent());
    }

    public function test_the_customers_direct_cancellation_tells_the_assigned_shopper_only_and_a_repeat_sends_nothing_again(): void
    {
        $shopper = $this->withDevice(Role::Shopper);
        $customer = $this->withDevice(Role::Customer);
        $order = Order::factory()->shoppingAssigned()->create(['customer_id' => $customer->id]);
        $order->shopperAssignments()->update(['shopper_id' => $shopper->id]);

        $this->cancelByCustomer($order, $customer)->assertOk();
        $this->cancelByCustomer($order, $customer)->assertOk();

        $this->assertPushed(['shopping_order_cancelled' => $shopper]);
    }

    public function test_the_customers_direct_cancellation_of_an_unassigned_order_tells_nobody(): void
    {
        $customer = $this->withDevice(Role::Customer);
        $order = Order::factory()->create(['customer_id' => $customer->id]);

        $this->cancelByCustomer($order, $customer)->assertOk();

        $this->assertSame([], $this->sent());
    }

    public function test_the_customers_cancellation_request_tells_nobody(): void
    {
        $shopper = $this->withDevice(Role::Shopper);
        $customer = $this->withDevice(Role::Customer);
        $this->withDevice(Role::Operator);
        $order = $this->shopped($shopper, $customer);

        $this->cancelByCustomer($order, $customer, 'Planlar ozgardi')->assertOk();

        $this->assertSame(1, OrderCancellationRequest::query()->count());
        $this->assertSame([], $this->sent());
    }

    public function test_the_operators_cancellation_after_a_failed_delivery_tells_the_customer(): void
    {
        $customer = $this->withDevice(Role::Customer);
        $operator = $this->withDevice(Role::Operator);
        $order = Order::factory()->deliveryFailed()->create(['customer_id' => $customer->id]);

        $this->as($operator)->postJson("/api/v1/operations/orders/{$order->id}/cancel", ['reason_code' => 'delivery_failed'])->assertOk();
        $this->as($operator)->postJson("/api/v1/operations/orders/{$order->id}/cancel", ['reason_code' => 'delivery_failed'])->assertOk();

        $this->assertPushed(['order_cancelled' => $customer]);
    }

    public function test_an_approved_request_tells_the_customer_and_the_shopper_and_a_repeat_sends_nothing_again(): void
    {
        $shopper = $this->withDevice(Role::Shopper);
        $customer = $this->withDevice(Role::Customer);
        $operator = $this->withDevice(Role::Operator);
        $order = $this->shopped($shopper, $customer);
        $request = OrderCancellationRequest::factory()->create(['order_id' => $order->id]);

        $this->decideRequest($request, $operator, 'approve')->assertOk();
        $this->assertPushed(['order_cancelled' => $customer, 'shopping_order_cancelled' => $shopper]);

        $this->forgetPushes();
        $this->decideRequest($request, $operator, 'approve')->assertOk();
        $this->assertSame([], $this->sent());
    }

    public function test_an_approved_request_in_delivery_assigned_tells_the_courier(): void
    {
        $courier = $this->withDevice(Role::Courier);
        $customer = $this->withDevice(Role::Customer);
        $operator = $this->withDevice(Role::Operator);
        $order = Order::factory()->deliveryAssigned()->create(['customer_id' => $customer->id]);
        $order->courierAssignments()->update(['courier_id' => $courier->id]);
        $request = OrderCancellationRequest::factory()->create(['order_id' => $order->id]);

        $this->decideRequest($request, $operator, 'approve')->assertOk();

        $this->assertPushed(['order_cancelled' => $customer, 'delivery_cancelled' => $courier]);
    }

    public function test_a_rejected_request_tells_the_customer_and_a_repeat_sends_nothing_again(): void
    {
        $shopper = $this->withDevice(Role::Shopper);
        $customer = $this->withDevice(Role::Customer);
        $operator = $this->withDevice(Role::Operator);
        $order = $this->shopped($shopper, $customer);
        $request = OrderCancellationRequest::factory()->create(['order_id' => $order->id]);

        $this->decideRequest($request, $operator, 'reject')->assertOk();
        $this->decideRequest($request, $operator, 'reject')->assertOk();

        $this->assertPushed(['cancellation_rejected' => $customer]);
    }

    public function test_a_blocked_shopper_gets_a_skipped_row_and_no_push(): void
    {
        $shopper = $this->withDevice(Role::Shopper);
        $customer = $this->withDevice(Role::Customer);
        $approval = $this->waiting($this->shopped($shopper, $customer));
        $shopper->forceFill(['status' => UserStatus::Blocked, 'blocked_at' => now()])->save();

        $this->decide($approval, $customer, 'approve')->assertOk();

        $this->assertSame([], $this->sent());
        $this->assertSame(NotificationDeliveryStatus::Skipped, NotificationDelivery::query()->where('user_id', $shopper->id)->sole()->status);
    }

    public function test_erasing_a_customer_with_delivery_rows_succeeds(): void
    {
        $phone = '+998900000078';
        config(['login_codes.test_phones' => [$phone], 'login_codes.test_code' => '000000']);
        $this->app->forgetInstance(TestPhones::class);
        $customer = User::factory()->customer()->create(['phone' => $phone]);
        PushDevice::factory()->create(['user_id' => $customer->id]);
        $order = Order::factory()->create(['customer_id' => $customer->id]);
        $this->cancelByCustomer($order, $customer)->assertOk();
        NotificationDelivery::factory()->create([
            'user_id' => $customer->id,
            'push_device_id' => PushDevice::query()->where('user_id', $customer->id)->value('id'),
            'order_id' => $order->id,
        ]);

        $this->as($customer)->postJson('/api/v1/customer/account/deletion-code')->assertOk();
        $this->as($customer)->postJson('/api/v1/customer/account/delete', ['code' => '000000'])->assertNoContent();

        $row = NotificationDelivery::query()->where('user_id', $customer->id)->sole();
        $this->assertNull($row->push_device_id);
        $this->assertSame(0, PushDevice::query()->where('user_id', $customer->id)->count());
    }
}
