<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Enums\PaymentMethod;
use App\Models\Enums\PaymentProvider;
use App\Models\Enums\PaymentStatus;
use Database\Factories\PaymentFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * An order's payment (`08` Section 21): in Wave 3 the cash the Courier
 * records at handover (`BR-PAY-003`); from Wave 5 also the online obligation
 * whose success only the provider confirms (`BR-PAY-004`). At most one live
 * payment per order.
 *
 * Nothing is mass-assignable: a payment is written by the delivery action and,
 * later, by the provider's events.
 *
 * @property string $id
 * @property string $order_id
 * @property PaymentMethod $method
 * @property PaymentProvider|null $provider
 * @property int $amount_uzs
 * @property PaymentStatus $status
 * @property Carbon|null $attention_at
 * @property Carbon|null $paid_at
 * @property Carbon|null $cancelled_at
 * @property string|null $recorded_by_user_id
 * @property Carbon $created_at
 * @property Carbon $updated_at
 */
class Payment extends Model
{
    /** @use HasFactory<PaymentFactory> */
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
            'method' => PaymentMethod::class,
            'provider' => PaymentProvider::class,
            'amount_uzs' => 'integer',
            'status' => PaymentStatus::class,
            'attention_at' => 'datetime',
            'paid_at' => 'datetime',
            'cancelled_at' => 'datetime',
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
    public function recordedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'recorded_by_user_id');
    }
}
