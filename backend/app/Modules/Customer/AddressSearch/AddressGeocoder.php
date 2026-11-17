<?php

declare(strict_types=1);

namespace App\Modules\Customer\AddressSearch;

/**
 * Looks up an address typed in words (`DL-86` item 1). Returns the point, or
 * null when nothing narrower than a city was found.
 */
interface AddressGeocoder
{
    /**
     * @throws GeocoderUnavailable when the provider cannot answer
     */
    public function locate(string $query, ?SearchBounds $bounds): ?LocatedPoint;

    /**
     * Names the point under the map pin (`DL-138` item 3), or null when
     * nothing is known there.
     *
     * @throws GeocoderUnavailable when the provider cannot answer
     */
    public function describe(string $latitude, string $longitude, string $language): ?PointAddress;
}
