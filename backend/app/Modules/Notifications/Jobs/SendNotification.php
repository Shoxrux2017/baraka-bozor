<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Jobs;

use App\Models\Enums\NotificationDeliveryStatus;
use App\Models\Enums\NotificationType;
use App\Models\Enums\UserStatus;
use App\Models\NotificationDelivery;
use App\Models\PushDevice;
use App\Models\User;
use App\Modules\Notifications\NotificationService;
use App\Modules\Notifications\NotificationText;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Support\Carbon;

/**
 * Decides who gets the push and writes the delivery rows. It carries scalars
 * only: an erased account must not break unserialisation.
 */
final class SendNotification implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;

    /** One try: a retry after a partial fan-out would duplicate rows and pushes. */
    public int $tries = 1;

    public function __construct(
        public readonly string $type,
        public readonly string $recipientUserId,
        public readonly string $orderId,
        public readonly int $orderNumber,
        public readonly ?int $amountUzs,
        public readonly ?string $approvalId,
        public readonly string $queuedAt,
    ) {}

    public function handle(NotificationText $text): void
    {
        $recipient = User::query()->find($this->recipientUserId);

        if ($recipient === null) {
            return;
        }

        if ($recipient->status !== UserStatus::Active) {
            $this->skip($recipient->id, 'account_inactive');

            return;
        }

        if (Carbon::parse($this->queuedAt)->addSeconds(NotificationService::MAX_AGE_SECONDS)->isPast()) {
            $this->skip($recipient->id, 'expired');

            return;
        }

        $devices = PushDevice::query()
            ->where('user_id', $recipient->id)
            ->whereNull('revoked_at')
            ->get();

        if ($devices->isEmpty()) {
            $this->skip($recipient->id, 'no_device');

            return;
        }

        $type = NotificationType::from($this->type);
        $rendered = $text->render($type, $recipient->preferred_language, $this->orderNumber, $this->amountUzs);
        $data = ['event' => $type->value, 'order_id' => $this->orderId];

        foreach ($devices as $device) {
            $row = $this->record($recipient->id, $device->id, NotificationDeliveryStatus::Queued, null);

            DeliverPush::dispatch($row->id, $rendered['title'], $rendered['body'], $data, $this->queuedAt);
        }
    }

    private function skip(string $userId, string $errorCode): void
    {
        $this->record($userId, null, NotificationDeliveryStatus::Skipped, $errorCode);
    }

    private function record(
        string $userId,
        ?string $deviceId,
        NotificationDeliveryStatus $status,
        ?string $errorCode,
    ): NotificationDelivery {
        $row = (new NotificationDelivery)->forceFill([
            'user_id' => $userId,
            'push_device_id' => $deviceId,
            'order_id' => $this->orderId,
            'approval_id' => $this->approvalId,
            'type' => NotificationType::from($this->type),
            'status' => $status,
            'attempt_count' => 0,
            'last_error_code' => $errorCode,
        ]);
        $row->save();

        return $row;
    }
}
