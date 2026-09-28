<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Enums\CancellationRequestOrigin;
use App\Models\Enums\CancellationRequestStatus;
use Database\Factories\OrderCancellationRequestFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * A request to cancel an order after shopping started (`08` Section 20,
 * `BR-CAN-002`): at most one pending per order, decided by an Operator or an
 * Admin, or closed when the order was cancelled another way first
 * (`DL-54` (12)).
 *
 * Nothing is mass-assignable: filing, deciding and closing are actions.
 *
 * @property string $id
 * @property string $order_id
 * @property CancellationRequestOrigin $origin
 * @property string $requested_by_user_id
 * @property CancellationRequestStatus $status
 * @property string $reason
 * @property string|null $resolved_by_user_id
 * @property string|null $resolution_note
 * @property Carbon|null $resolved_at
 * @property Carbon $created_at
 * @property Carbon $updated_at
 */
class OrderCancellationRequest extends Model
{
    /** @use HasFactory<OrderCancellationRequestFactory> */
    use HasFactory;

    use HasUuids;

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
            'origin' => CancellationRequestOrigin::class,
            'status' => CancellationRequestStatus::class,
            'resolved_at' => 'datetime',
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
    public function requestedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'requested_by_user_id');
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function resolvedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'resolved_by_user_id');
    }
}
