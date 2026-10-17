<?php

declare(strict_types=1);

namespace App\Modules\Customer\AddressSearch;

/**
 * Bound while no geocoding key is set: every lookup is unavailable, and
 * nothing is sent anywhere.
 */
final class UnconfiguredGeocoder implements AddressGeocoder
{
    public function locate(#[\SensitiveParameter] string $query, ?SearchBounds $bounds): ?LocatedPoint
    {
        throw new GeocoderUnavailable;
    }
}
