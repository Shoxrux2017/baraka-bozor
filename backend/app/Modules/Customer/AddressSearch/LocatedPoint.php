<?php

declare(strict_types=1);

namespace App\Modules\Customer\AddressSearch;

/**
 * A point a typed address was looked up to, as the decimal strings the API
 * and the address columns use: six decimals.
 */
final readonly class LocatedPoint
{
    public string $latitude;

    public string $longitude;

    public function __construct(float $latitude, float $longitude)
    {
        $this->latitude = number_format($latitude, 6, '.', '');
        $this->longitude = number_format($longitude, 6, '.', '');
    }
}
