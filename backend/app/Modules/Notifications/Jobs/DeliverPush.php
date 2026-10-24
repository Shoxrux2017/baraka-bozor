<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Jobs;

use App\Models\Enums\NotificationDeliveryStatus;
use App\Models\NotificationDelivery;
use App\Models\PushDevice;
use App\Modules\Notifications\NotificationService;
use App\Modules\Notifications\Push\PushMessage;
use App\Modules\Notifications\Push\PushSender;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Support\Carbon;
use Throwable;

/**
 * Sends one push to one device and records the outcome. The token is read
 * from the device row at send time; it is never in the payload or a log.
 */
final class DeliverPush implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;

    /** Seconds to wait before the next try, by the number of tries made. */
    private const array BACKOFF_SECONDS = [30, 120, 600];

    public int $tries = 4;

    /**
     * @param  array<string, string>  $data
     */
    public function __construct(
        public readonly string $deliveryId,
        public readonly string $title,
        public readonly string $body,
        public readonly array $data,
        public readonly string $queuedAt,
    ) {}

    public function handle(PushSender $sender): void
    {
        $row = NotificationDelivery::query()->find($this->deliveryId);

        if ($row === null || $row->status !== NotificationDeliveryStatus::Queued) {
            return;
        }

        $device = $row->push_device_id === null ? null : PushDevice::query()->find($row->push_device_id);

        if ($device === null || $device->revoked_at !== null) {
            $this->finish($row, NotificationDeliveryStatus::Failed, 'device_revoked');

            return;
        }

        if (Carbon::parse($this->queuedAt)->addSeconds(NotificationService::MAX_AGE_SECONDS)->isPast()) {
            $this->finish($row, NotificationDeliveryStatus::Failed, 'expired');

            return;
        }

        $row->attempt_count++;
        $result = $sender->send($device->push_token, new PushMessage($this->title, $this->body, $this->data));

        if ($result->sent) {
            $row->sent_at = now();
            $this->finish($row, NotificationDeliveryStatus::Sent, null);

            return;
        }

        if ($result->retryable && $this->attempts() < $this->tries) {
            $row->last_error_code = $result->errorCode;
            $row->save();

            $this->release(self::BACKOFF_SECONDS[min($row->attempt_count, count(self::BACKOFF_SECONDS)) - 1]);

            return;
        }

        $this->finish($row, NotificationDeliveryStatus::Failed, $result->errorCode);
    }

    public function failed(Throwable $exception): void
    {
        $row = NotificationDelivery::query()->find($this->deliveryId);

        if ($row !== null && $row->status === NotificationDeliveryStatus::Queued) {
            $this->finish($row, NotificationDeliveryStatus::Failed, 'exception');
        }
    }

    private function finish(NotificationDelivery $row, NotificationDeliveryStatus $status, ?string $errorCode): void
    {
        $row->status = $status;
        $row->last_error_code = $errorCode;
        $row->save();
    }
}
