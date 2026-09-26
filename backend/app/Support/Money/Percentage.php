<?php

declare(strict_types=1);

namespace App\Support\Money;

use InvalidArgumentException;

/**
 * A non-negative percentage with at most two decimal places, held as integer
 * basis points (1 % = 100 bp) so that no percentage ever passes through binary
 * floating point on its way to a price (`BR-MONEY-002`, `DL-17` (2)).
 *
 * It arrives as the decimal string the API and the `numeric(5,2)` columns
 * carry — `"15"`, `"12.5"`, `"12.50"` — at most `"999.99"`.
 */
final class Percentage
{
    private const PATTERN = '/^(\d{1,3})(?:\.(\d{1,2}))?\z/';

    private function __construct(public readonly int $basisPoints) {}

    public static function fromString(string $value): self
    {
        if (preg_match(self::PATTERN, $value, $parts) !== 1) {
            throw new InvalidArgumentException(
                'A percentage is a non-negative decimal string with at most three integer digits and two decimals.'
            );
        }

        $fraction = str_pad($parts[2] ?? '', 2, '0');

        return new self(((int) $parts[1]) * 100 + (int) $fraction);
    }
}
