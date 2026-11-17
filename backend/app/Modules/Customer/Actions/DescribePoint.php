<?php

declare(strict_types=1);

namespace App\Modules\Customer\Actions;

use App\Exceptions\ApiException;
use App\Models\User;
use App\Modules\Customer\AddressSearch\AddressGeocoder;
use App\Modules\Customer\AddressSearch\GeocoderUnavailable;
use App\Modules\Customer\AddressSearch\PointAddress;
use Illuminate\Cache\RateLimiter;

/**
 * `POST /customer/address-search/reverse` (`docs/09` section 13, `DL-138`
 * item 3).
 *
 * Names the point under the map pin. Ten lookups a minute and thirty a day per
 * Customer, counted apart from the searches so moving the map never uses up
 * the search; a lookup counts when it starts. Neither the point nor the
 * provider's answer is stored or logged.
 */
final class DescribePoint
{
    public const PER_MINUTE = 10;

    public const PER_DAY = 30;

    public function __construct(
        private readonly RateLimiter $limiter,
        private readonly AddressGeocoder $geocoder,
    ) {}

    public function __invoke(User $customer, string $latitude, string $longitude, string $language): ?PointAddress
    {
        $this->reserve("address-reverse:minute:{$customer->id}", self::PER_MINUTE, 60);
        $this->reserve("address-reverse:day:{$customer->id}", self::PER_DAY, 86_400);

        try {
            return $this->geocoder->describe($latitude, $longitude, $language);
        } catch (GeocoderUnavailable) {
            throw ApiException::unavailable('provider_unavailable');
        }
    }

    /**
     * Take one slot under $key, or refuse when it is beyond the limit.
     */
    private function reserve(string $key, int $max, int $decaySeconds): void
    {
        if ($this->limiter->hit($key, $decaySeconds) > $max) {
            throw ApiException::tooManyRequests('rate_limited', $this->limiter->availableIn($key));
        }
    }
}
