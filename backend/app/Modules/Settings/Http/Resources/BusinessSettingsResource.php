<?php

declare(strict_types=1);

namespace App\Modules\Settings\Http\Resources;

use App\Models\BusinessSettings;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Every business setting of `docs/08-database.md` section 11, with `null` for
 * what Admin has not configured yet. Percentages, coordinates and the radius
 * are decimal strings; times are `HH:MM` in `Asia/Tashkent`.
 *
 * @property-read BusinessSettings $resource
 */
final class BusinessSettingsResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $settings = $this->resource;

        return [
            'markup_percent' => $settings->markup_percent,
            'service_fee_mode' => $settings->service_fee_mode->value,
            'service_fee_fixed_uzs' => $settings->service_fee_fixed_uzs,
            'service_fee_percent' => $settings->service_fee_percent,
            'delivery_fee_uzs' => $settings->delivery_fee_uzs,
            'minimum_order_uzs' => $settings->minimum_order_uzs,
            'price_tolerance_percent' => $settings->price_tolerance_percent,
            'opens_at' => self::hoursAndMinutes($settings->opens_at),
            'closes_at' => self::hoursAndMinutes($settings->closes_at),
            'service_centre_latitude' => $settings->service_centre_latitude,
            'service_centre_longitude' => $settings->service_centre_longitude,
            'service_radius_km' => $settings->service_radius_km,
            'delivery_delay_threshold_minutes' => $settings->delivery_delay_threshold_minutes,
            'updated_at' => $settings->updated_at->toIso8601ZuluString(),
        ];
    }

    private static function hoursAndMinutes(?string $time): ?string
    {
        return $time === null ? null : substr($time, 0, 5);
    }
}
