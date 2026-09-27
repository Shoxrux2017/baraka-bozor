<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Enums\CancellationReason;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderStatus;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * One row of an order's history (`08` Section 15). Append-only: the database
 * refuses an update or a delete (`order_history_append_only`), so there is no
 * `updated_at`.
 *
 * @property string $id
 * @property string $order_id
 * @property OrderHistoryEvent $event_type
 * @property OrderStatus|null $from_status
 * @property OrderStatus|null $to_status
 * @property HistoryActorType $actor_type
 * @property string|null $actor_user_id
 * @property CancellationReason|null $reason_code
 * @property string|null $note
 * @property array<string, mixed>|null $details
 * @property Carbon $created_at
 */
class OrderHistory extends Model
{
    use HasUuids;

    public const UPDATED_AT = null;

    protected $table = 'order_history';

    /**
     * @var list<string>
     */
    protected $fillable = [];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'event_type' => OrderHistoryEvent::class,
            'from_status' => OrderStatus::class,
            'to_status' => OrderStatus::class,
            'actor_type' => HistoryActorType::class,
            'reason_code' => CancellationReason::class,
            'details' => 'array',
        ];
    }

    /**
     * @return BelongsTo<Order, $this>
     */
    public function order(): BelongsTo
    {
        return $this->belongsTo(Order::class);
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function actor(): BelongsTo
    {
        return $this->belongsTo(User::class, 'actor_user_id');
    }
}
