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
}
