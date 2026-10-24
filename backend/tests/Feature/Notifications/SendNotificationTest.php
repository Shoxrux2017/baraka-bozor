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
use App\Modules\Notifications\Jobs\DeliverPush;
use App\Modules\Notifications\Jobs\SendNotification;
use App\Modules\Notifications\NotificationText;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Str;
use Tests\TestCase;

final class SendNotificationTest extends TestCase
{
    use RefreshDatabase;

    private function job(string $recipientId, ?Order $order = null, ?string $queuedAt = null): SendNotification
    {
        $order ??= Order::factory()->create()->refresh();

        return new SendNotification(
            NotificationType::OrderDelivered->value,
            $recipientId,
            $order->id,
            $order->order_number,
            null,
            null,
            $queuedAt ?? now()->toIso8601String(),
        );
    }

    public function test_an_inactive_account_gets_one_skipped_row(): void
    {
        Queue::fake();
        $shopper = User::factory()->role(Role::Shopper)->blocked()->create();
        PushDevice::factory()->create(['user_id' => $shopper->id]);

        $this->job($shopper->id)->handle(new NotificationText);

        Queue::assertNotPushed(DeliverPush::class);
        $row = NotificationDelivery::sole();
        $this->assertSame(NotificationDeliveryStatus::Skipped, $row->status);
        $this->assertSame('account_inactive', $row->last_error_code);
        $this->assertNull($row->push_device_id);
        $this->assertSame($shopper->id, $row->user_id);
    }

    public function test_an_account_with_no_active_device_gets_one_skipped_row(): void
    {
        Queue::fake();
        $customer = User::factory()->customer()->create();
        PushDevice::factory()->revoked()->create(['user_id' => $customer->id]);

        $this->job($customer->id)->handle(new NotificationText);

        Queue::assertNotPushed(DeliverPush::class);
        $row = NotificationDelivery::sole();
        $this->assertSame(NotificationDeliveryStatus::Skipped, $row->status);
        $this->assertSame('no_device', $row->last_error_code);
    }

    public function test_a_push_queued_over_an_hour_ago_is_skipped(): void
    {
        Queue::fake();
        $customer = User::factory()->customer()->create();
        PushDevice::factory()->create(['user_id' => $customer->id]);
        $job = $this->job($customer->id);

        $this->travel(61)->minutes();
        $job->handle(new NotificationText);

        Queue::assertNotPushed(DeliverPush::class);
        $row = NotificationDelivery::sole();
        $this->assertSame(NotificationDeliveryStatus::Skipped, $row->status);
        $this->assertSame('expired', $row->last_error_code);
    }

    public function test_each_active_device_gets_a_queued_row_and_a_delivery_job(): void
    {
        Queue::fake();
        $customer = User::factory()->customer()->create();
        PushDevice::factory()->count(2)->create(['user_id' => $customer->id]);
        PushDevice::factory()->revoked()->create(['user_id' => $customer->id]);
        $order = Order::factory()->create(['customer_id' => $customer->id])->refresh();

        $this->job($customer->id, $order)->handle(new NotificationText);

        $rows = NotificationDelivery::all();
        $this->assertCount(2, $rows);
        foreach ($rows as $row) {
            $this->assertSame(NotificationDeliveryStatus::Queued, $row->status);
            $this->assertSame(0, $row->attempt_count);
            $this->assertSame($customer->id, $row->user_id);
            $this->assertSame($order->id, $row->order_id);
            $this->assertSame(NotificationType::OrderDelivered, $row->type);
            $this->assertNotNull($row->push_device_id);
        }
        Queue::assertPushed(DeliverPush::class, 2);
        Queue::assertPushed(DeliverPush::class, fn (DeliverPush $j): bool => $j->data === ['event' => 'order_delivered', 'order_id' => $order->id]);
    }

    public function test_the_text_is_in_the_recipients_language(): void
    {
        Queue::fake();
        $customer = User::factory()->customer()->create(['preferred_language' => 'ru']);
        PushDevice::factory()->create(['user_id' => $customer->id]);

        $this->job($customer->id)->handle(new NotificationText);

        Queue::assertPushed(DeliverPush::class, fn (DeliverPush $j): bool => $j->title === 'Заказ доставлен');
    }

    public function test_a_missing_recipient_writes_nothing(): void
    {
        Queue::fake();

        $this->job((string) Str::uuid())->handle(new NotificationText);

        Queue::assertNothingPushed();
        $this->assertSame(0, NotificationDelivery::count());
    }

    public function test_the_job_is_tried_once(): void
    {
        $this->assertSame(1, $this->job((string) Str::uuid())->tries);
    }
}
