<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Enums\ApprovalResolution;
use App\Models\Enums\ApprovalStatus;
use App\Models\Enums\ApprovalType;
use App\Models\Enums\UnitCode;
use Database\Factories\CustomerApprovalFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * A question put to the Customer about one line (`08` Section 18): a higher
 * price, a replacement or a smaller quantity. The proposal is fixed when it
 * is made (`BR-APP-001`); only its resolution changes. It reaches the
 * Operator at `attention_at` and expires at `expires_at` (`BR-APP-002`,
 * `BR-APP-003`), and expiry is never consent (`BR-APP-004`).
 *
 * Nothing is mass-assignable: the Shopper's question, the Customer's decision,
 * the expiry and the Operator's resolution are actions.
 *
 * @property string $id
 * @property string $order_id
 * @property string $order_item_id
 * @property ApprovalType $type
 * @property ApprovalStatus $status
 * @property string $requested_by_user_id
 * @property int|null $proposed_customer_unit_price_uzs
 * @property int|null $proposed_actual_market_price_uzs
 * @property string|null $proposed_quantity
 * @property string|null $replacement_product_id
 * @property string|null $replacement_name_uz_snapshot
 * @property string|null $replacement_name_ru_snapshot
 * @property UnitCode|null $replacement_unit_code_snapshot
 * @property string|null $request_note
 * @property Carbon $attention_at
 * @property Carbon $expires_at
 * @property string|null $resolved_by_user_id
 * @property Carbon|null $resolved_at
 * @property ApprovalResolution|null $resolution
 * @property Carbon $created_at
 * @property Carbon $updated_at
 */
class CustomerApproval extends Model
{
    /** @use HasFactory<CustomerApprovalFactory> */
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
            'type' => ApprovalType::class,
            'status' => ApprovalStatus::class,
            'proposed_customer_unit_price_uzs' => 'integer',
            'proposed_actual_market_price_uzs' => 'integer',
            'proposed_quantity' => 'decimal:3',
            'replacement_unit_code_snapshot' => UnitCode::class,
            'attention_at' => 'datetime',
            'expires_at' => 'datetime',
            'resolved_at' => 'datetime',
            'resolution' => ApprovalResolution::class,
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
     * @return BelongsTo<OrderItem, $this>
     */
    public function item(): BelongsTo
    {
        return $this->belongsTo(OrderItem::class, 'order_item_id');
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function requestedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'requested_by_user_id');
    }

    /**
     * @return BelongsTo<Product, $this>
     */
    public function replacementProduct(): BelongsTo
    {
        return $this->belongsTo(Product::class, 'replacement_product_id');
    }

    /**
     * @return BelongsTo<User, $this>
     */
    public function resolvedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'resolved_by_user_id');
    }
}
