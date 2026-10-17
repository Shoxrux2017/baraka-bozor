<?php

declare(strict_types=1);

namespace App\Modules\Customer\Actions;

use App\Exceptions\ApiException;
use App\Models\BusinessSettings;
use App\Models\User;
use App\Modules\Customer\AddressSearch\AddressGeocoder;
use App\Modules\Customer\AddressSearch\GeocoderUnavailable;
use App\Modules\Customer\AddressSearch\LocatedPoint;
use App\Modules\Customer\AddressSearch\SearchBounds;
use Illuminate\Cache\RateLimiter;

/**
 * `POST /customer/address-search` (`docs/09` section 13, `DL-86` item 1).
 *
 * Looks a typed address up and answers only a point. Ten searches a minute
 * and thirty a day per Customer; a search counts when it starts, so a failing
 * provider is bounded like everything else. Neither the query nor the
 * provider's answer is stored or logged.
 */
final class SearchAddress
{
    public const PER_MINUTE = 10;

    public const PER_DAY = 30;

    /** Kilometres in one degree of latitude. */
    private const KM_PER_DEGREE = 111.32;

    public function __construct(
        private readonly RateLimiter $limiter,
        private readonly AddressGeocoder $geocoder,
    ) {}

    public function __invoke(User $customer, #[\SensitiveParameter] string $query): ?LocatedPoint
    {
        $this->reserve("address-search:minute:{$customer->id}", self::PER_MINUTE, 60);
        $this->reserve("address-search:day:{$customer->id}", self::PER_DAY, 86_400);

        try {
            return $this->geocoder->locate($query, $this->serviceAreaBox());
        } catch (GeocoderUnavailable) {
            throw ApiException::unavailable('provider_unavailable');
        }
    }

    /**
     * The service circle's bounding box, or null while no area is set.
     */
    private function serviceAreaBox(): ?SearchBounds
    {
        $settings = BusinessSettings::current();

        if ($settings->service_centre_latitude === null
            || $settings->service_centre_longitude === null
            || $settings->service_radius_km === null) {
            return null;
        }

        $latitude = (float) $settings->service_centre_latitude;
        $longitude = (float) $settings->service_centre_longitude;
        $radius = (float) $settings->service_radius_km;

        $latitudeSpan = $radius / self::KM_PER_DEGREE;
        $longitudeSpan = $radius / (self::KM_PER_DEGREE * cos(deg2rad($latitude)));

        return new SearchBounds(
            south: $latitude - $latitudeSpan,
            west: $longitude - $longitudeSpan,
            north: $latitude + $latitudeSpan,
            east: $longitude + $longitudeSpan,
        );
    }

    /**
     * Take one slot under $key, or refuse when it is beyond the limit. The
     * increment is atomic in the cache, so a burst cannot slip under a limit.
     */
    private function reserve(string $key, int $max, int $decaySeconds): void
    {
        if ($this->limiter->hit($key, $decaySeconds) > $max) {
            throw ApiException::tooManyRequests('rate_limited', $this->limiter->availableIn($key));
        }
    }
}
