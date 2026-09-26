<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Enums\ServiceFeeMode;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;

/**
 * The one row of business settings (`08` Section 11, `BR-SET-001`).
 *
 * The row exists from the migration that created the table (`DL-17`), so
 * [current] never creates one and never finds none. Percentages and
 * coordinates are strings, as the API carries them (`09` Section 1); the
 * settings task turns a percentage into basis points before any arithmetic.
 *
 * Nothing is fillable: the settings action assigns each validated field by
 * name, and `updated_by_user_id` is the authenticated Admin.
 *
 * @property int $id
 * @property string $markup_percent
 * @property ServiceFeeMode $service_fee_mode
 * @property int|null $service_fee_fixed_uzs
 * @property string|null $service_fee_percent
 * @property int|null $delivery_fee_uzs
 * @property int|null $minimum_order_uzs
 * @property string $price_tolerance_percent
 * @property string|null $opens_at
 * @property string|null $closes_at
 * @property string|null $service_centre_latitude
 * @property string|null $service_centre_longitude
 * @property string|null $service_radius_km
 * @property int $delivery_delay_threshold_minutes
 * @property string|null $updated_by_user_id
 * @property Carbon $created_at
 * @property Carbon $updated_at
 */
class BusinessSettings extends Model
{
    public const SINGLETON_ID = 1;

    protected $table = 'business_settings';

    public $incrementing = false;

    protected $keyType = 'int';

    /**
     * @var list<string>
     */
    protected $fillable = [];

    /**
     * The settings row.
     */
    public static function current(): self
    {
        return self::query()->findOrFail(self::SINGLETON_ID);
    }

    /**
     * @return array<string, string>
     */
    protected function casts(): array
    {
        return [
            'markup_percent' => 'decimal:2',
            'service_fee_mode' => ServiceFeeMode::class,
            'service_fee_fixed_uzs' => 'integer',
            'service_fee_percent' => 'decimal:2',
            'delivery_fee_uzs' => 'integer',
            'minimum_order_uzs' => 'integer',
            'price_tolerance_percent' => 'decimal:2',
            'service_centre_latitude' => 'decimal:6',
            'service_centre_longitude' => 'decimal:6',
            'service_radius_km' => 'decimal:2',
            'delivery_delay_threshold_minutes' => 'integer',
        ];
    }
}
