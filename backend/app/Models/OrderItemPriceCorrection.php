<?php

declare(strict_types=1);

namespace App\Models;

use Database\Factories\OrderItemPriceCorrectionFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Support\Carbon;

/**
 * An Admin's correction of a recorded purchase price (`08` Section 19,
 * `BR-PRICE-006`). Append-only: the database refuses an update or a delete
 * (`order_item_price_corrections_append_only`), so there is no `updated_at`.
 *
 * @property string $id
 * @property string $order_item_id
 * @property int $old_actual_market_price_uzs
 * @property int $new_actual_market_price_uzs
 * @property int $old_billable_unit_price_uzs
 * @property int $new_billable_unit_price_uzs
 * @property string $corrected_by_user_id
 * @property string $reason
 * @property Carbon $created_at
 */
class OrderItemPriceCorrection extends Model
{
    /** @use HasFactory<OrderItemPriceCorrectionFactory> */
    use HasFactory;

    use HasUuids;

    public const UPDATED_AT = null;

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
            'old_actual_market_price_uzs' => 'integer',
            'new_actual_market_price_uzs' => 'integer',
            'old_billable_unit_price_uzs' => 'integer',
            'new_billable_unit_price_uzs' => 'integer',
        ];
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
    public function correctedBy(): BelongsTo
    {
        return $this->belongsTo(User::class, 'corrected_by_user_id');
    }
}
