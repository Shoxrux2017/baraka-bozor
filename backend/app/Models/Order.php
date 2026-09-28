<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\CancellationReason;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\PaymentMethod;
use App\Models\Enums\PaymentStatus;
use App\Models\Enums\ServiceFeeMode;
use Database\Factories\OrderFactory;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Support\Carbon;

/**
 * An order (`08` Section 13) with the snapshots it was placed under.
 *
 * Nothing is mass-assignable. Every column is written by an action that owns
 * the transition (`BR-ORDER-002`), and a snapshot is copied from the state the
 * checkout token bound (`DL-37` (4)), never from request input.
 *
 * `order_number` comes from its sequence (`DL-37` (2)) and is read back after
 * insert rather than chosen here.
 *
 * @property string $id
 * @property int $order_number
 * @property string $customer_id
 * @property string $source_cart_id
 * @property string $source_address_id
 * @property OrderStatus $status
 * @property PaymentMethod $payment_method
 * @property string|null $delivery_time_note
 * @property string $recipient_name_snapshot
 * @property string $recipient_phone_snapshot
 * @property string $latitude_snapshot
 * @property string $longitude_snapshot
 * @property string $street_snapshot
 * @property string $house_snapshot
 * @property string|null $apartment_snapshot
 * @property string|null $landmark_snapshot
 * @property string|null $delivery_note_snapshot
 * @property string $markup_percent_snapshot
 * @property string $price_tolerance_percent_snapshot
 * @property ServiceFeeMode $service_fee_mode_snapshot
 * @property int|null $service_fee_fixed_uzs_snapshot
 * @property string|null $service_fee_percent_snapshot
 * @property int $delivery_fee_uzs_snapshot
 * @property int $delivery_delay_threshold_minutes_snapshot
 * @property int|null $final_merchandise_subtotal_uzs
 * @property int|null $final_service_fee_uzs
 * @property int|null $final_total_uzs
 * @property Carbon|null $shopping_started_at
 * @property Carbon|null $shopping_completed_at
 * @property Carbon|null $ready_for_delivery_at
 * @property Carbon|null $on_the_way_at
 * @property Carbon|null $completed_at
 * @property Carbon|null $cancelled_at
 * @property CancellationReason|null $cancellation_reason_code
 * @property Carbon $created_at
 * @property Carbon $updated_at
 */
class Order extends Model
{
    /** @use HasFactory<OrderFactory> */
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
            'order_number' => 'integer',
            'status' => OrderStatus::class,
            'payment_method' => PaymentMethod::class,
            'latitude_snapshot' => 'decimal:6',
            'longitude_snapshot' => 'decimal:6',
            'markup_percent_snapshot' => 'decimal:2',
            'price_tolerance_percent_snapshot' => 'decimal:2',
            'service_fee_mode_snapshot' => ServiceFeeMode::class,
            'service_fee_fixed_uzs_snapshot' => 'integer',
            'service_fee_percent_snapshot' => 'decimal:2',
            'delivery_fee_uzs_snapshot' => 'integer',
            'delivery_delay_threshold_minutes_snapshot' => 'integer',
            'final_merchandise_subtotal_uzs' => 'integer',
            'final_service_fee_uzs' => 'integer',
            'final_total_uzs' => 'integer',
            'shopping_started_at' => 'datetime',
            'shopping_completed_at' => 'datetime',
            'ready_for_delivery_at' => 'datetime',
            'on_the_way_at' => 'datetime',
            'completed_at' => 'datetime',
            'cancelled_at' => 'datetime',
            'cancellation_reason_code' => CancellationReason::class,
        ];
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function customer(): BelongsTo
    {
        return $this->belongsTo(User::class, 'customer_id');
    }

    /**
     * @return BelongsTo<Cart, $this>
     */
    public function sourceCart(): BelongsTo
    {
        return $this->belongsTo(Cart::class, 'source_cart_id');
    }

    /**
     * @return BelongsTo<CustomerAddress, $this>
     */
    public function sourceAddress(): BelongsTo
    {
        return $this->belongsTo(CustomerAddress::class, 'source_address_id');
    }

    /**
     * @return HasMany<OrderItem, $this>
     */
    public function items(): HasMany
    {
        return $this->hasMany(OrderItem::class);
    }

    /**
     * @return HasMany<OrderHistory, $this>
     */
    public function history(): HasMany
    {
        return $this->hasMany(OrderHistory::class);
    }

    /**
     * @return HasMany<OrderShopperAssignment, $this>
     */
    public function shopperAssignments(): HasMany
    {
        return $this->hasMany(OrderShopperAssignment::class);
    }

    /**
     * The assignment that has not ended; the database allows at most one
     * (`order_shopper_assignments_order_current_unique`).
     *
     * @return HasOne<OrderShopperAssignment, $this>
     */
    public function currentShopperAssignment(): HasOne
    {
        return $this->hasOne(OrderShopperAssignment::class)->whereNull('ended_at');
    }

    /**
     * The Shopper assignment the board names (`DL-54` (14)): the current one,
     * or else the one that completed the shopping. At most one matches, since
     * an order is shopped once and nothing is assigned after its completion.
     *
     * @return HasOne<OrderShopperAssignment, $this>
     */
    public function namedShopperAssignment(): HasOne
    {
        return $this->hasOne(OrderShopperAssignment::class)->where(static fn (Builder $assignment) => $assignment
            ->whereNull('ended_at')
            ->orWhere('ended_reason', AssignmentEndReason::Completed->value));
    }

    /**
     * @return HasMany<OrderCourierAssignment, $this>
     */
    public function courierAssignments(): HasMany
    {
        return $this->hasMany(OrderCourierAssignment::class);
    }

    /**
     * The Courier assignment that has not ended; the database allows at most
     * one (`order_courier_assignments_order_current_unique`).
     *
     * @return HasOne<OrderCourierAssignment, $this>
     */
    public function currentCourierAssignment(): HasOne
    {
        return $this->hasOne(OrderCourierAssignment::class)->whereNull('ended_at');
    }

    /**
     * The Courier assignment the board names (`DL-54` (14)): the current one,
     * or else the one that delivered. At most one matches, since a delivered
     * order is assigned no further Courier.
     *
     * @return HasOne<OrderCourierAssignment, $this>
     */
    public function namedCourierAssignment(): HasOne
    {
        return $this->hasOne(OrderCourierAssignment::class)->where(static fn (Builder $assignment) => $assignment
            ->whereNull('ended_at')
            ->orWhere('ended_reason', AssignmentEndReason::Completed->value));
    }

    /**
     * @return HasMany<CustomerApproval, $this>
     */
    public function approvals(): HasMany
    {
        return $this->hasMany(CustomerApproval::class);
    }

    /**
     * @return HasMany<OrderCancellationRequest, $this>
     */
    public function cancellationRequests(): HasMany
    {
        return $this->hasMany(OrderCancellationRequest::class);
    }

    /**
     * Every payment of the order, a cancelled online obligation included; the
     * database allows one that is not cancelled (`payments_order_live_unique`).
     *
     * @return HasMany<Payment, $this>
     */
    public function payments(): HasMany
    {
        return $this->hasMany(Payment::class);
    }

    /**
     * The payment not cancelled; the database allows at most one
     * (`payments_order_live_unique`).
     *
     * @return HasOne<Payment, $this>
     */
    public function livePayment(): HasOne
    {
        return $this->hasOne(Payment::class)->where('status', '<>', PaymentStatus::Cancelled->value);
    }
}
