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
use Illuminate\Log\Events\MessageLogged;
use Illuminate\Queue\Jobs\FakeJob;
use Illuminate\Support\Facades\Event;
use RuntimeException;
use Tests\TestCase;

final class DeliverPushTest extends TestCase
{
    use RefreshDatabase;

    private FakePushSender $push;

    /** @var list<array{level: string, message: string, context: array<string, mixed>}> */
    private array $logs = [];

    protected function setUp(): void
    {
        parent::setUp();

        $this->push = $this->app->make(FakePushSender::class);
        $this->logs = [];

        Event::listen(MessageLogged::class, function (MessageLogged $event): void {
            $this->logs[] = ['level' => $event->level, 'message' => $event->message, 'context' => $event->context];
        });
    }

    /**
     * @return list<array<string, mixed>> the contexts of the "given up" warnings
     */
    private function givenUp(): array
    {
        $contexts = [];
        foreach ($this->logs as $log) {
            if ($log['level'] === 'warning' && $log['message'] === 'A push was given up.') {
                $contexts[] = $log['context'];
            }
        }

        return $contexts;
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

    public function test_a_rejected_token_revokes_its_device_and_fails_the_row(): void
    {
        [$row, $device] = $this->queuedRow();
        $other = PushDevice::factory()->create(['user_id' => $device->user_id]);
        $this->push->answerNext(PushSendResult::rejectedToken('UNREGISTERED'));

        $job = $this->job($row);
        $job->handle($this->push);

        $row->refresh();
        $this->assertSame(NotificationDeliveryStatus::Failed, $row->status);
        $this->assertSame('UNREGISTERED', $row->last_error_code);
        $this->assertSame(1, $row->attempt_count);
        $this->assertNotNull($device->refresh()->revoked_at);
        $this->assertNull($other->refresh()->revoked_at);
        $job->assertNotReleased();
    }

    public function test_a_retry_after_longer_than_the_backoff_is_honoured(): void
    {
        $this->travelTo(now()->startOfSecond());
        [$row] = $this->queuedRow();
        $this->push->answerNext(PushSendResult::retry('QUOTA_EXCEEDED', 300));

        $job = $this->job($row);
        $job->handle($this->push);

        $job->assertReleased(delay: 300);
    }

    public function test_a_retry_after_shorter_than_the_backoff_keeps_the_backoff(): void
    {
        $this->travelTo(now()->startOfSecond());
        [$row] = $this->queuedRow([], ['attempt_count' => 1]);
        $this->push->answerNext(PushSendResult::retry('UNAVAILABLE', 5));

        $job = $this->job($row, 2);
        $job->handle($this->push);

        $job->assertReleased(delay: 120);
    }

    public function test_a_retry_that_would_land_past_the_hour_fails_now(): void
    {
        $this->travelTo(now()->startOfSecond());
        [$row] = $this->queuedRow();
        $this->push->answerNext(PushSendResult::retry('UNAVAILABLE', 3700));

        $job = $this->job($row);
        $job->handle($this->push);

        $row->refresh();
        $this->assertSame(NotificationDeliveryStatus::Failed, $row->status);
        $this->assertSame('UNAVAILABLE', $row->last_error_code);
        $job->assertNotReleased();
    }

    public function test_a_push_given_up_after_its_retries_is_logged(): void
    {
        [$row] = $this->queuedRow([], ['attempt_count' => 3]);
        $this->push->answerNext(PushSendResult::retry('UNAVAILABLE'));

        $this->job($row, 4)->handle($this->push);

        $this->assertSame([['reason' => 'UNAVAILABLE']], $this->givenUp());
    }

    public function test_a_retry_past_the_hour_is_logged_as_given_up(): void
    {
        $this->travelTo(now()->startOfSecond());
        [$row] = $this->queuedRow();
        $this->push->answerNext(PushSendResult::retry('UNAVAILABLE', 3700));

        $this->job($row)->handle($this->push);

        $this->assertSame([['reason' => 'UNAVAILABLE']], $this->givenUp());
    }

    public function test_a_released_retry_logs_nothing(): void
    {
        [$row] = $this->queuedRow();
        $this->push->answerNext(PushSendResult::retry('UNAVAILABLE'));

        $this->job($row)->handle($this->push);

        $this->assertSame([], $this->givenUp());
    }

    public function test_a_permanent_failure_is_not_logged_by_the_job(): void
    {
        [$row] = $this->queuedRow();
        $this->push->answerNext(PushSendResult::failed('INVALID_ARGUMENT'));

        $this->job($row)->handle($this->push);

        $this->assertSame([], $this->givenUp());
    }

    public function test_a_retry_near_the_end_of_the_hour_fits_only_while_the_delay_does(): void
    {
        $this->travelTo(now()->startOfSecond());
        [$row] = $this->queuedRow();
        [$late] = $this->queuedRow([], ['attempt_count' => 2]);
        $job = $this->job($row);
        $lateJob = $this->job($late, 3);

        $this->travel(55)->minutes();
        $this->push->answerNext(PushSendResult::retry('UNAVAILABLE'));
        $job->handle($this->push);

        $job->assertReleased(delay: 30);
        $this->assertSame(NotificationDeliveryStatus::Queued, $row->refresh()->status);

        $this->travel(4)->minutes();
        $this->push->answerNext(PushSendResult::retry('UNAVAILABLE'));
        $lateJob->handle($this->push);

        $lateJob->assertNotReleased();
        $this->assertSame(NotificationDeliveryStatus::Failed, $late->refresh()->status);
    }

    public function test_the_push_carries_its_remaining_lifetime(): void
    {
        $this->travelTo(now()->startOfSecond());
        [$row] = $this->queuedRow();
        [$later] = $this->queuedRow();
        $job = $this->job($row);
        $laterJob = $this->job($later);

        $job->handle($this->push);
        $this->travel(10)->minutes();
        $laterJob->handle($this->push);

        $this->assertSame(3600, $this->push->sent()[0]['message']->ttlSeconds);
        $this->assertSame(3000, $this->push->sent()[1]['message']->ttlSeconds);
    }

    public function test_the_delivery_id_is_the_push_tag(): void
    {
        [$row] = $this->queuedRow();
        $this->push->answerNext(PushSendResult::retry('UNAVAILABLE'));

        $this->job($row)->handle($this->push);
        $this->job($row, 2)->handle($this->push);

        $this->assertSame($row->id, $this->push->sent()[0]['message']->tag);
        $this->assertSame($row->id, $this->push->sent()[1]['message']->tag);
    }

    public function test_a_fake_that_does_not_report_delivery_marks_the_row_failed_without_sent_at(): void
    {
        [$row] = $this->queuedRow();

        $this->job($row)->handle(new FakePushSender(reportsDelivery: false));

        $row->refresh();
        $this->assertSame(NotificationDeliveryStatus::Failed, $row->status);
        $this->assertSame('fake_driver', $row->last_error_code);
        $this->assertNull($row->sent_at);
    }
}
