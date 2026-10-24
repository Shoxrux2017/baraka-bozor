<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Enums\NotificationDeliveryStatus;
use App\Models\Enums\NotificationType;
use Database\Factories\NotificationDeliveryFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * One push to one device, or one skipped row without a device (`08`
 * Section 26). Written only by the notification jobs, so nothing is fillable.
 *
 * @property string $id
 * @property string $user_id
 * @property string|null $push_device_id
 * @property string|null $order_id
 * @property string|null $approval_id
 * @property NotificationType $type
 * @property NotificationDeliveryStatus $status
 * @property int $attempt_count
 * @property Carbon|null $sent_at
 * @property string|null $last_error_code
 * @property Carbon $created_at
 * @property Carbon $updated_at
 */
class NotificationDelivery extends Model
{
    /** @use HasFactory<NotificationDeliveryFactory> */
    use HasFactory;

    use HasUuids;

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'type' => NotificationType::class,
            'status' => NotificationDeliveryStatus::class,
            'attempt_count' => 'integer',
            'sent_at' => 'datetime',
        ];
    }

    /**
     * @return BelongsTo<PushDevice, $this>
     */
    public function pushDevice(): BelongsTo
    {
        return $this->belongsTo(PushDevice::class);
    }
}
