<?php

declare(strict_types=1);

namespace App\Models;

use Database\Factories\OrderRatingFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * A Customer's rating of a delivered order (`08` Section 33, `BR-RATE-001`):
 * one per order, 1 to 5 stars, reasons only at 1 to 3, a comment, and the
 * Operator's review of a low one (`BR-RATE-003`).
 *
 * Nothing is mass-assignable: rating and reviewing are actions.
 *
 * @property string $id
 * @property string $order_id
 * @property string $customer_id
 * @property int $stars
 * @property list<string> $reasons
 * @property string|null $comment
 * @property string|null $reviewed_by_user_id
 * @property Carbon|null $reviewed_at
 * @property Carbon $created_at
 * @property Carbon $updated_at
 */
class OrderRating extends Model
{
    /** @use HasFactory<OrderRatingFactory> */
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
            'stars' => 'integer',
            'reasons' => 'array',
            'reviewed_at' => 'datetime',
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
    public function customer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'customer_id');
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function reviewedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'reviewed_by_user_id');
    }
}
