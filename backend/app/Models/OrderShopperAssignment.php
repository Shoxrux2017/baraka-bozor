<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Enums\AssignmentEndReason;
use Database\Factories\OrderShopperAssignmentFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * A Shopper's assignment to an order (`08` Section 16). It ends rather than
 * being deleted, and at most one per order has not ended (`BR-CON-002`).
 * `is_self_order` is fixed when it is made, from the phones (`BR-ASSIGN-005`).
 *
 * Nothing is mass-assignable: who assigned whom, and when an assignment ends,
 * are the assignment actions' to decide.
 *
 * @property string $id
 * @property string $order_id
 * @property string $shopper_id
 * @property string $assigned_by_user_id
 * @property bool $is_self_order
 * @property Carbon $assigned_at
 * @property Carbon|null $accepted_at
 * @property Carbon|null $started_at
 * @property Carbon|null $completed_at
 * @property Carbon|null $ended_at
 * @property AssignmentEndReason|null $ended_reason
 * @property Carbon $created_at
 * @property Carbon $updated_at
 */
class OrderShopperAssignment extends Model
{
    /** @use HasFactory<OrderShopperAssignmentFactory> */
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
            'started_at' => 'datetime',
            'completed_at' => 'datetime',
            'ended_at' => 'datetime',
            'ended_reason' => AssignmentEndReason::class,
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
    public function shopper(): BelongsTo
    {
        return $this->belongsTo(User::class, 'shopper_id');
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function assignedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'assigned_by_user_id');
    }
}
