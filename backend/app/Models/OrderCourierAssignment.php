<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\DeliveryFailureReason;
use Database\Factories\OrderCourierAssignmentFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * A Courier's assignment to an order (`08` Section 17). It ends rather than
 * being deleted, and at most one per order has not ended (`BR-CON-002`). The
 * start of the delivery fixes when the order becomes late (`BR-DEL-002`); a
 * failed delivery keeps its reason (`BR-DEL-003`).
 *
 * Nothing is mass-assignable: the assignment and delivery actions decide
 * every column.
 *
 * @property string $id
 * @property string $order_id
 * @property string $courier_id
 * @property string $assigned_by_user_id
 * @property bool $is_self_order
 * @property Carbon $assigned_at
 * @property Carbon|null $accepted_at
 * @property Carbon|null $delivery_started_at
 * @property Carbon|null $delay_at
 * @property Carbon|null $completed_at
 * @property Carbon|null $ended_at
 * @property AssignmentEndReason|null $ended_reason
 * @property DeliveryFailureReason|null $failed_reason_code
 * @property string|null $failed_note
 * @property Carbon $created_at
 * @property Carbon $updated_at
 */
class OrderCourierAssignment extends Model
{
    /** @use HasFactory<OrderCourierAssignmentFactory> */
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
            'is_self_order' => 'boolean',
            'assigned_at' => 'datetime',
            'accepted_at' => 'datetime',
            'delivery_started_at' => 'datetime',
            'delay_at' => 'datetime',
            'completed_at' => 'datetime',
            'ended_at' => 'datetime',
            'ended_reason' => AssignmentEndReason::class,
            'failed_reason_code' => DeliveryFailureReason::class,
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
    public function courier(): BelongsTo
    {
        return $this->belongsTo(User::class, 'courier_id');
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function assignedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'assigned_by_user_id');
    }
}
