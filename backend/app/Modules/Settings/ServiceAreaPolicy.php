<?php

declare(strict_types=1);

namespace App\Modules\Settings;

use App\Exceptions\ApiException;
use App\Models\BusinessSettings;

/**
 * The service area of `BR-AREA-001`: a circle of `service_radius_km` around
 * the configured centre, measured as the great-circle distance
 * (`docs/07-architecture.md` section 11). Floating point is fine here; a
 * distance is not money.
 *
 * Address saving (Wave 1) and checkout (Wave 2) ask the same question, so the
 * two refusals live here: `409 checkout_configuration_incomplete` while the
 * centre or the radius is unset (`DL-17` (7)), and
 * `422 address_outside_service_area` with both distances as two-decimal
 * strings so the client can compose its own sentence (`docs/09` section 13).
 * The distance shown is rounded up, so a point a few metres beyond a 5.00 km
 * radius reads "5.01", never "5.00 km away, we deliver within 5.00 km".
 */
final class ServiceAreaPolicy
{
    /** The mean Earth radius (IUGG), in kilometres. */
    public const EARTH_RADIUS_KM = 6371.0088;

    public function assertDeliverable(string $latitude, string $longitude): void
    {
        $settings = BusinessSettings::current();

        if ($settings->service_centre_latitude === null
            || $settings->service_centre_longitude === null
            || $settings->service_radius_km === null) {
            throw ApiException::conflict('checkout_configuration_incomplete');
        }

        $distance = self::distanceKm(
            $settings->service_centre_latitude,
            $settings->service_centre_longitude,
            $latitude,
            $longitude,
        );

        if (! self::isWithin($distance, $settings->service_radius_km)) {
            throw ApiException::unprocessable('address_outside_service_area', [
                'max_distance_km' => $settings->service_radius_km,
                'distance_km' => number_format(ceil($distance * 100) / 100, 2, '.', ''),
            ]);
        }
    }

    /**
     * `BR-AREA-001`: a point is refused only when it lies farther than the
     * radius; a point exactly on the circle is inside.
     */
    public static function isWithin(float $distanceKm, string $radiusKm): bool
    {
        return $distanceKm <= (float) $radiusKm;
    }

    /**
     * The haversine distance between two points given in decimal degrees.
     */
    public static function distanceKm(string $fromLatitude, string $fromLongitude, string $toLatitude, string $toLongitude): float
    {
        $phi1 = deg2rad((float) $fromLatitude);
        $phi2 = deg2rad((float) $toLatitude);
        $deltaPhi = $phi2 - $phi1;
        $deltaLambda = deg2rad((float) $toLongitude - (float) $fromLongitude);

        $a = sin($deltaPhi / 2) ** 2 + cos($phi1) * cos($phi2) * sin($deltaLambda / 2) ** 2;

        return 2 * self::EARTH_RADIUS_KM * asin(min(1.0, sqrt($a)));
    }
}
