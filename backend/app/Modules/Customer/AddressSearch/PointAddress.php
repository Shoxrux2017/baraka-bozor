<?php

declare(strict_types=1);

namespace App\Modules\Customer\AddressSearch;

/**
 * The words that name a point on the map (`DL-138` item 3): shown beside the
 * pin, never stored. `houseKnown` says the line reaches a house, not only a
 * street or a district. The line is cut to 160 characters, the street
 * column's length.
 */
final readonly class PointAddress
{
    public const MAX_LENGTH = 160;

    public string $line;

    public function __construct(string $line, public bool $houseKnown)
    {
        $this->line = mb_substr($line, 0, self::MAX_LENGTH);
    }
}
