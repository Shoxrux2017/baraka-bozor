<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Jobs;

use App\Models\Enums\NotificationDeliveryStatus;
use App\Models\NotificationDelivery;
use App\Models\PushDevice;
use App\Modules\Notifications\Actions\RevokePushDevice;
use App\Modules\Notifications\NotificationService;
use App\Modules\Notifications\Push\PushMessage;
use App\Modules\Notifications\Push\PushSender;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Log;
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

        $expiresAt = Carbon::parse($this->queuedAt)->addSeconds(NotificationService::MAX_AGE_SECONDS);

        if ($expiresAt->isPast()) {
            $this->finish($row, NotificationDeliveryStatus::Failed, 'expired');

            return;
        }

        $row->attempt_count++;
        $ttlSeconds = max(1, $expiresAt->getTimestamp() - now()->getTimestamp());
        $result = $sender->send($device->push_token, new PushMessage($this->title, $this->body, $this->data, $ttlSeconds, tag: $row->id));

        if ($result->sent) {
            $row->sent_at = now();
            $this->finish($row, NotificationDeliveryStatus::Sent, null);

            return;
        }

        if ($result->revokesDevice) {
            RevokePushDevice::refusedByProvider($device->id);
            $this->finish($row, NotificationDeliveryStatus::Failed, $result->errorCode);

            return;
        }

        if ($result->retryable && $this->attempts() < $this->tries) {
            $delay = max(
                self::BACKOFF_SECONDS[min($row->attempt_count, count(self::BACKOFF_SECONDS)) - 1],
                $result->retryAfterSeconds ?? 0,
            );

            if ($expiresAt->getTimestamp() <= now()->getTimestamp() + $delay) {
                $this->giveUp($row, $result->errorCode);

                return;
            }

            $row->last_error_code = $result->errorCode;
            $row->save();

            $this->release($delay);

            return;
        }

        if ($result->retryable) {
            $this->giveUp($row, $result->errorCode);

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

    /**
     * A transient failure that ends the row: the only trace of a blocked
     * network or a persistent refusal is this reason, never an id or a token.
     */
    private function giveUp(NotificationDelivery $row, ?string $errorCode): void
    {
        Log::warning('A push was given up.', ['reason' => $errorCode]);
        $this->finish($row, NotificationDeliveryStatus::Failed, $errorCode);
    }

    private function finish(NotificationDelivery $row, NotificationDeliveryStatus $status, ?string $errorCode): void
    {
        $row->status = $status;
        $row->last_error_code = $errorCode;
        $row->save();
    }
}
