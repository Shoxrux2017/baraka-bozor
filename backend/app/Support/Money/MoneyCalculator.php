<?php

declare(strict_types=1);

namespace App\Support\Money;

use InvalidArgumentException;

/**
 * The one place a UZS amount is rounded (`docs/07-architecture.md` section 14,
 * `BR-MONEY-001` to `BR-MONEY-003`).
 *
 * Integer arithmetic only: a percentage is basis points, the product is formed
 * exactly, and the single division rounds half up to 1 UZS. Amounts in this
 * system are never negative, so "half up" and "half away from zero" agree, and
 * the method refuses a negative input rather than pick one.
 *
 * The largest intermediate is an amount times `10000 + 99999`; with amounts in
 * the billions of UZS that stays far below the 64-bit limit.
 */
final class MoneyCalculator
{
    private const BASIS = 10_000;

    /**
     * `half_up(amount × (1 + percent / 100))` — the customer price from the
     * market price and the markup (`BR-PRICE-001`), and later the estimate
     * ceiling from the tolerance (`BR-PRICE-003`).
     */
    public static function increaseByPercent(int $amountUzs, Percentage $percent): int
    {
        self::assertNotNegative($amountUzs);

        return self::divideHalfUp($amountUzs * (self::BASIS + $percent->basisPoints), self::BASIS);
    }

    /**
     * `numerator / denominator`, rounded half up to a whole UZS, for
     * non-negative numerators and positive denominators.
     */
    private static function divideHalfUp(int $numerator, int $denominator): int
    {
        return intdiv($numerator * 2 + $denominator, $denominator * 2);
    }

    private static function assertNotNegative(int $amountUzs): void
    {
        if ($amountUzs < 0) {
            throw new InvalidArgumentException('A UZS amount is never negative.');
        }
    }
}
