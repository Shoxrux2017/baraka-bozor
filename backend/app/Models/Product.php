<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Enums\PriceMode;
use App\Models\Enums\UnitCode;
use Database\Factories\ProductFactory;
use Illuminate\Database\Eloquent\Concerns\HasUuids;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;
use Illuminate\Support\Carbon;

/**
 * A catalog product (`08` Section 7).
 *
 * There is no customer price here on purpose: it is computed from the market
 * price and the current markup on every read (`BR-PRICE-001`, `DL-17`). Order
 * snapshots are where a price gets written down.
 *
 * `is_active`, `archived_at` and `created_by_user_id` are outside `$fillable`
 * for the same reasons as on `Category`; `category_id` is inside it because
 * the category is ordinary input the admin form sends, validated to exist and
 * to be unarchived by the action that saves it.
 *
 * @property string $id
 * @property string $category_id
 * @property string $name_uz
 * @property string $name_ru
 * @property string|null $description_uz
 * @property string|null $description_ru
 * @property UnitCode $unit_code
 * @property PriceMode $price_mode
 * @property int $market_price_uzs
 * @property bool $is_active
 * @property int $sort_order
 * @property Carbon|null $archived_at
 * @property string $created_by_user_id
 * @property Carbon $created_at
 * @property Carbon $updated_at
 */
class Product extends Model
{
    /** @use HasFactory<ProductFactory> */
    use HasFactory;

    use HasUuids;

    /**
     * @var list<string>
     */
    protected $fillable = [
        'category_id',
        'name_uz',
        'name_ru',
        'description_uz',
        'description_ru',
        'unit_code',
        'price_mode',
        'market_price_uzs',
        'sort_order',
    ];

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'unit_code' => UnitCode::class,
            'price_mode' => PriceMode::class,
            'market_price_uzs' => 'integer',
            'is_active' => 'boolean',
            'sort_order' => 'integer',
            'archived_at' => 'datetime',
        ];
    }

    /**
     * @return BelongsTo<Category, $this>
     */
    public function category(): BelongsTo
    {
        return $this->belongsTo(Category::class);
    }

    /**
     * @return HasOne<ProductImage, $this>
     */
    public function image(): HasOne
    {
        return $this->hasOne(ProductImage::class);
    }
}
