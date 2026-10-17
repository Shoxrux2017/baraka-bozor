<?php

declare(strict_types=1);

namespace App\Modules\Customer\AddressSearch;

/**
 * The box a lookup is biased toward: the service area's circle, as a
 * south-west and a north-east corner in degrees.
 */
final readonly class SearchBounds
{
    public function __construct(
        public float $south,
        public float $west,
        public float $north,
        public float $east,
    ) {}
}
