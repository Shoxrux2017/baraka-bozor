<?php

declare(strict_types=1);

namespace App\Support\Money;

use InvalidArgumentException;

/**
 * A quantity as whole thousandths, so the three decimals `numeric(18,3)` holds
 * (`docs/08` section 1) are exact and a line total is computed without a float
 * (`BR-MONEY-002`). Which units take a fraction, and how much of one, is the
 * order's `QuantityPolicy`; this only reads and writes the number.
 */
final readonly class Quantity
{
    private const PATTERN = '/^(\d{1,15})(?:\.(\d{1,3}))?\z/';

    private function __construct(public int $thousandths) {}

    /**
     * From a non-negative decimal string with at most three decimals, as the
     * API sends quantities and the database returns them (`"5"`, `"1.25"`,
     * `"5.000"`).
     */
    public static function fromString(string $value): self
    {
        if (preg_match(self::PATTERN, $value, $parts) !== 1) {
            throw new InvalidArgumentException('A quantity is a non-negative decimal string with at most three decimals.');
        }

        return new self((int) $parts[1] * 1000 + (int) str_pad($parts[2] ?? '', 3, '0'));
    }

    public function isWhole(): bool
    {
        return $this->thousandths % 1000 === 0;
    }

    /** With three decimals, as the database stores it: `"1.500"`. */
    public function toDecimal(): string
    {
        return sprintf('%d.%03d', intdiv($this->thousandths, 1000), $this->thousandths % 1000);
    }

    /** Without a fraction: `"2"`. Only for a whole quantity. */
    public function toWhole(): string
    {
        if (! $this->isWhole()) {
            throw new InvalidArgumentException('The quantity has a fraction.');
        }

        return (string) intdiv($this->thousandths, 1000);
    }
}
