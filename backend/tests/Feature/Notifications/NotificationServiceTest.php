<?php

declare(strict_types=1);

namespace Tests\Feature\Notifications;

use App\Models\Enums\NotificationDeliveryStatus;
use App\Models\Enums\NotificationType;
use App\Models\Enums\Role;
use App\Models\NotificationDelivery;
use App\Models\Order;
use App\Models\PushDevice;
use App\Models\User;
use App\Modules\Notifications\NotificationService;
use App\Modules\Notifications\Push\FakePushSender;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use RuntimeException;
use Tests\TestCase;

final class NotificationServiceTest extends TestCase
{
    use RefreshDatabase;

    private NotificationService $service;

    private FakePushSender $push;

    protected function setUp(): void
    {
        parent::setUp();

        $this->service = $this->app->make(NotificationService::class);
        $this->push = $this->app->make(FakePushSender::class);
    }

    private function withDevice(Role $role): User
    {
        $user = User::factory()->role($role)->create();
        PushDevice::factory()->create(['user_id' => $user->id]);

        return $user;
    }

    public function test_a_committed_call_sends_one_push_with_the_event_and_order_id_only(): void
    {
        $customer = $this->withDevice(Role::Customer);
        $courier = User::factory()->role(Role::Courier)->create();
        $order = Order::factory()->create(['customer_id' => $customer->id])->refresh();

        DB::transaction(fn () => $this->service->notify(NotificationType::OrderDelivered, $customer->id, $order, $courier->id));

        $sent = $this->push->sent();
        $this->assertCount(1, $sent);
        $this->assertSame(PushDevice::where('user_id', $customer->id)->value('push_token'), $sent[0]['token']);
        $this->assertSame(['event' => 'order_delivered', 'order_id' => $order->id], $sent[0]['message']->data);

        $row = NotificationDelivery::sole();
        $this->assertSame(NotificationDeliveryStatus::Sent, $row->status);
        $this->assertSame(1, $row->attempt_count);
        $this->assertNotNull($row->sent_at);
    }

    public function test_a_rolled_back_transaction_sends_nothing(): void
    {
        $customer = $this->withDevice(Role::Customer);
        $order = Order::factory()->create(['customer_id' => $customer->id])->refresh();

        try {
            DB::transaction(function () use ($customer, $order): void {
                $this->service->notify(NotificationType::OrderDelivered, $customer->id, $order, null);

                throw new RuntimeException('the action failed afterwards');
            });
        } catch (RuntimeException) {
            // The failure is the point of the test.
        }

        $this->assertSame([], $this->push->sent());
        $this->assertSame(0, NotificationDelivery::count());
    }

    public function test_the_actor_is_not_told_of_their_own_action(): void
    {
        $courier = $this->withDevice(Role::Courier);
        $order = Order::factory()->create()->refresh();

        $this->service->notify(NotificationType::CourierStarted, $courier->id, $order, $courier->id);

        $this->assertSame([], $this->push->sent());
        $this->assertSame(0, NotificationDelivery::count());
    }

    public function test_order_accepted_reaches_the_customer_who_placed_it(): void
    {
        $customer = $this->withDevice(Role::Customer);
        $order = Order::factory()->create(['customer_id' => $customer->id])->refresh();

        $this->service->notify(NotificationType::OrderAccepted, $customer->id, $order, $customer->id);

        $this->assertCount(1, $this->push->sent());
    }

    public function test_a_cancellation_tells_the_customer_the_shopper_and_the_courier_but_not_the_actor(): void
    {
        $customer = $this->withDevice(Role::Customer);
        $shopper = $this->withDevice(Role::Shopper);
        $courier = $this->withDevice(Role::Courier);
        $operator = User::factory()->role(Role::Operator)->create();
        $order = Order::factory()->create(['customer_id' => $customer->id])->refresh();

        $this->service->notifyCancellation($order, $operator->id, $shopper->id, $courier->id);

        $events = array_map(fn (array $s): string => $s['message']->data['event'], $this->push->sent());
        sort($events);
        $this->assertSame(['delivery_cancelled', 'order_cancelled', 'shopping_order_cancelled'], $events);

        $this->service->notifyCancellation($order, $shopper->id, $shopper->id, $courier->id);

        $this->assertCount(5, $this->push->sent());
        $latest = array_map(fn (array $s): string => $s['message']->data['event'], array_slice($this->push->sent(), 3));
        sort($latest);
        $this->assertSame(['delivery_cancelled', 'order_cancelled'], $latest);
    }

    public function test_the_amount_reaches_the_shopping_completed_text(): void
    {
        $customer = $this->withDevice(Role::Customer);
        $order = Order::factory()->create(['customer_id' => $customer->id])->refresh();
        $order->final_total_uzs = 251250;

        $this->service->notify(NotificationType::ShoppingCompleted, $customer->id, $order, null);

        $this->assertStringContainsString('251', $this->push->sent()[0]['message']->body);
    }
}
