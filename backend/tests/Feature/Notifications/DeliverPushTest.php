<?php

declare(strict_types=1);

namespace Tests\Feature\Notifications;

use App\Models\Enums\NotificationDeliveryStatus;
use App\Models\NotificationDelivery;
use App\Models\PushDevice;
use App\Modules\Notifications\Jobs\DeliverPush;
use App\Modules\Notifications\Push\FakePushSender;
use App\Modules\Notifications\Push\PushSendResult;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Queue\Jobs\FakeJob;
use RuntimeException;
use Tests\TestCase;

final class DeliverPushTest extends TestCase
{
    use RefreshDatabase;

    private FakePushSender $push;

    protected function setUp(): void
    {
        parent::setUp();

        $this->push = $this->app->make(FakePushSender::class);
    }

    /**
     * @param  array<string, mixed>  $device
     * @param  array<string, mixed>  $delivery
     * @return array{NotificationDelivery, PushDevice}
     */
    private function queuedRow(array $device = [], array $delivery = []): array
    {
        $pushDevice = PushDevice::factory()->create($device);
        $row = NotificationDelivery::factory()->create([
            'user_id' => $pushDevice->user_id,
            'push_device_id' => $pushDevice->id,
            ...$delivery,
        ]);

        return [$row, $pushDevice];
    }

    private function job(NotificationDelivery $row, int $attempts = 1): DeliverPush
    {
        $job = new DeliverPush(
            $row->id,
            'Title',
            'Body',
            ['event' => 'order_accepted', 'order_id' => 'o-1'],
            now()->toIso8601String(),
        );
        $job->withFakeQueueInteractions();
        $fake = $job->job;
        assert($fake instanceof FakeJob);
        $fake->attempts = $attempts;

        return $job;
    }

    public function test_a_sent_push_marks_the_row_sent(): void
    {
        [$row, $device] = $this->queuedRow();

        $this->job($row)->handle($this->push);

        $row->refresh();
        $this->assertSame(NotificationDeliveryStatus::Sent, $row->status);
        $this->assertSame(1, $row->attempt_count);
        $this->assertNotNull($row->sent_at);
        $this->assertSame($device->push_token, $this->push->sent()[0]['token']);
        $this->assertSame('Title', $this->push->sent()[0]['message']->title);
    }

    public function test_a_permanent_failure_marks_the_row_failed_with_its_code(): void
    {
        [$row] = $this->queuedRow();
        $this->push->answerNext(PushSendResult::failed('INVALID_ARGUMENT'));

        $job = $this->job($row);
        $job->handle($this->push);

        $row->refresh();
        $this->assertSame(NotificationDeliveryStatus::Failed, $row->status);
        $this->assertSame('INVALID_ARGUMENT', $row->last_error_code);
        $this->assertSame(1, $row->attempt_count);
        $job->assertNotReleased();
    }

    public function test_a_transient_failure_is_released_with_backoff(): void
    {
        [$row] = $this->queuedRow();
        $this->push->answerNext(PushSendResult::retry('UNAVAILABLE'));

        $job = $this->job($row);
        $job->handle($this->push);

        $job->assertReleased(delay: 30);
        $row->refresh();
        $this->assertSame(NotificationDeliveryStatus::Queued, $row->status);
        $this->assertSame(1, $row->attempt_count);
        $this->assertSame('UNAVAILABLE', $row->last_error_code);
    }

    public function test_the_backoff_grows_with_the_attempts(): void
    {
        [$row] = $this->queuedRow([], ['attempt_count' => 1]);
        $this->push->answerNext(PushSendResult::retry('UNAVAILABLE'));

        $job = $this->job($row, 2);
        $job->handle($this->push);

        $job->assertReleased(delay: 120);
    }

    public function test_the_fourth_transient_failure_marks_the_row_failed(): void
    {
        [$row] = $this->queuedRow([], ['attempt_count' => 3]);
        $this->push->answerNext(PushSendResult::retry('UNAVAILABLE'));

        $job = $this->job($row, 4);
        $job->handle($this->push);

        $job->assertNotReleased();
        $row->refresh();
        $this->assertSame(NotificationDeliveryStatus::Failed, $row->status);
        $this->assertSame('UNAVAILABLE', $row->last_error_code);
        $this->assertSame(4, $row->attempt_count);
    }

    public function test_a_retry_past_an_hour_is_not_sent(): void
    {
        [$row] = $this->queuedRow();
        $job = $this->job($row);

        $this->travel(61)->minutes();
        $job->handle($this->push);

        $row->refresh();
        $this->assertSame(NotificationDeliveryStatus::Failed, $row->status);
        $this->assertSame('expired', $row->last_error_code);
        $this->assertSame([], $this->push->sent());
    }

    public function test_a_revoked_device_is_not_sent_to(): void
    {
        [$row] = $this->queuedRow(['revoked_at' => now()]);

        $this->job($row)->handle($this->push);

        $row->refresh();
        $this->assertSame(NotificationDeliveryStatus::Failed, $row->status);
        $this->assertSame('device_revoked', $row->last_error_code);
        $this->assertSame([], $this->push->sent());
    }

    public function test_a_row_no_longer_queued_is_left_alone(): void
    {
        [$row] = $this->queuedRow([], ['status' => NotificationDeliveryStatus::Sent, 'attempt_count' => 1, 'sent_at' => now()]);

        $this->job($row)->handle($this->push);

        $row->refresh();
        $this->assertSame(NotificationDeliveryStatus::Sent, $row->status);
        $this->assertSame(1, $row->attempt_count);
        $this->assertSame([], $this->push->sent());
    }

    public function test_the_failed_hook_marks_a_queued_row_failed(): void
    {
        [$row] = $this->queuedRow();

        $this->job($row)->failed(new RuntimeException('boom'));

        $row->refresh();
        $this->assertSame(NotificationDeliveryStatus::Failed, $row->status);
        $this->assertSame('exception', $row->last_error_code);
    }
}
