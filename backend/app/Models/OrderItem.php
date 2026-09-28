<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Enums\ItemRemovedReason;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\PriceMode;
use App\Models\Enums\SubstitutionPolicy;
use App\Models\Enums\SubstitutionResolution;
use App\Models\Enums\UnitCode;
use Database\Factories\OrderItemFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Support\Carbon;

/**
 * An order line (`08` Section 14) with its own markup snapshot (`DL-37` (8)).
 *
 * Nothing is mass-assignable: quantities, prices and states are the backend's
 * to decide (`AGENTS.md` Section 5), and the snapshots are copied by the
 * actions from what the order was placed or edited under.
 *
 * @property string $id
 * @property string $order_id
 * @property string $product_id
 * @property string $product_name_uz_snapshot
 * @property string $product_name_ru_snapshot
 * @property UnitCode $unit_code_snapshot
 * @property PriceMode $price_mode_snapshot
 * @property int $market_price_uzs_snapshot
 * @property int $customer_unit_price_uzs_snapshot
 * @property string $markup_percent_snapshot
 * @property string $ordered_quantity
 * @property string|null $purchased_quantity
 * @property string $billable_quantity
 * @property string|null $customer_note_snapshot
 * @property SubstitutionPolicy $substitution_policy_snapshot
 * @property OrderItemStatus $status
 * @property string|null $approved_quantity_cap
 * @property int|null $approved_unit_price_ceiling_uzs
 * @property int|null $approved_replacement_price_uzs
 * @property string|null $fulfilled_product_id
 * @property string|null $fulfilled_product_name_uz_snapshot
 * @property string|null $fulfilled_product_name_ru_snapshot
 * @property UnitCode|null $fulfilled_unit_code_snapshot
 * @property SubstitutionResolution|null $substitution_resolution
 * @property int|null $actual_market_price_uzs
 * @property int|null $billable_unit_price_uzs
 * @property int|null $line_total_uzs
 * @property ItemRemovedReason|null $removed_reason_code
 * @property Carbon|null $removed_at
 * @property Carbon $created_at
 * @property Carbon $updated_at
 */
class OrderItem extends Model
{
    /** @use HasFactory<OrderItemFactory> */
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
            'unit_code_snapshot' => UnitCode::class,
            'price_mode_snapshot' => PriceMode::class,
            'market_price_uzs_snapshot' => 'integer',
            'customer_unit_price_uzs_snapshot' => 'integer',
            'markup_percent_snapshot' => 'decimal:2',
            'ordered_quantity' => 'decimal:3',
            'purchased_quantity' => 'decimal:3',
            'billable_quantity' => 'decimal:3',
            'substitution_policy_snapshot' => SubstitutionPolicy::class,
            'status' => OrderItemStatus::class,
            'approved_quantity_cap' => 'decimal:3',
            'approved_unit_price_ceiling_uzs' => 'integer',
            'approved_replacement_price_uzs' => 'integer',
            'fulfilled_unit_code_snapshot' => UnitCode::class,
            'substitution_resolution' => SubstitutionResolution::class,
            'actual_market_price_uzs' => 'integer',
            'billable_unit_price_uzs' => 'integer',
            'line_total_uzs' => 'integer',
            'removed_reason_code' => ItemRemovedReason::class,
            'removed_at' => 'datetime',
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
     * @return BelongsTo<Product, $this>
     */
    public function product(): BelongsTo
    {
        return $this->belongsTo(Product::class);
    }

    /**
     * @return BelongsTo<Product, $this>
     */
    public function fulfilledProduct(): BelongsTo
    {
        return $this->belongsTo(Product::class, 'fulfilled_product_id');
    }

    /**
     * @return HasMany<CustomerApproval, $this>
     */
    public function approvals(): HasMany
    {
        return $this->hasMany(CustomerApproval::class);
    }

    /**
     * @return HasMany<OrderItemPriceCorrection, $this>
     */
    public function priceCorrections(): HasMany
    {
        return $this->hasMany(OrderItemPriceCorrection::class);
    }
}
