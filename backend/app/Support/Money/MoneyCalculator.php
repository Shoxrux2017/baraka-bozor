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
 * The largest intermediate is `2 × amount × (10000 + 99999) + 10000`, which
 * stays inside a 64-bit integer for amounts up to about 4.19 × 10¹³ UZS. Every
 * amount that reaches here is bounded far below that by its request (a market
 * price at most 10⁹ UZS); beyond it PHP raises a `TypeError` rather than
 * rounding silently.
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
     * `half_up(amount × percent / 100)` — a percentage service fee on the
     * merchandise subtotal (`BR-MONEY-005`).
     */
    public static function percentOf(int $amountUzs, Percentage $percent): int
    {
        self::assertNotNegative($amountUzs);

        return self::divideHalfUp($amountUzs * $percent->basisPoints, self::BASIS);
    }

    /**
     * `half_up(unit price × quantity)` — a line total (`BR-MONEY-003`), and the
     * cart's estimate of one. The quantity is in thousandths, so the product is
     * exact. A customer price is at most a market price of 10⁹ UZS under the
     * largest markup the settings allow (999.99 %), about 1.1 × 10¹⁰; with a
     * quantity of at most 9 999.999 (`DL-37` (6)) the intermediate stays below
     * 2.3 × 10¹⁷, far inside a 64-bit integer.
     */
    public static function lineTotal(int $unitPriceUzs, Quantity $quantity): int
    {
        self::assertNotNegative($unitPriceUzs);

        return self::divideHalfUp($unitPriceUzs * $quantity->thousandths, 1000);
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
