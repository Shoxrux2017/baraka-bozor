<?php

declare(strict_types=1);

namespace App\Support\Money;

use InvalidArgumentException;
use OverflowException;

/**
 * The one place a UZS amount is rounded (`docs/07-architecture.md` section 14,
 * `BR-MONEY-001` to `BR-MONEY-003`).
 *
 * Integer arithmetic only: a percentage is basis points, the product is formed
 * exactly, and the single division rounds half up to 1 UZS. Amounts in this
 * system are never negative, so "half up" and "half away from zero" agree, and
 * the method refuses a negative input rather than pick one.
 *
 * `increaseByPercent` forms `2 × amount × (10000 + 99999) + 10000`, inside a
 * 64-bit integer for amounts up to about 4.19 × 10¹³ UZS; it takes a market
 * price, at most 10⁹ UZS. `percentOf` takes a subtotal, which the cart's
 * bounds let grow further, so it divides before it multiplies and is exact
 * for any amount. Sums go through `sum()`, which refuses to overflow rather
 * than let PHP turn the result into a float.
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
     * The largest whole amount that `increaseByPercent` keeps at or under the
     * ceiling — the highest market price a Shopper may pay without asking,
     * given the customer price the line may not exceed (`DL-54` (6)).
     *
     * `half_up(m × (10000 + bp) / 10000) ≤ C` exactly when
     * `2 × m × (10000 + bp) ≤ (2C + 1) × 10000 − 1`, since the rounded value
     * stays at or under C while the exact one stays under C + ½; the increase
     * never falls as the amount grows, so the largest such m is the floor of
     * that bound. The products stay inside a 64-bit integer for ceilings up to
     * about 4.6 × 10¹⁴ UZS, far above the largest a line can have (a customer
     * price of about 1.1 × 10¹⁰ under a tolerance of up to 999.99 %).
     */
    public static function largestBaseWithin(int $ceilingUzs, Percentage $percent): int
    {
        self::assertNotNegative($ceilingUzs);

        return intdiv((2 * $ceilingUzs + 1) * self::BASIS - 1, 2 * (self::BASIS + $percent->basisPoints));
    }

    /**
     * `half_up(amount × percent / 100)` — a percentage service fee on the
     * merchandise subtotal (`BR-MONEY-005`).
     */
    public static function percentOf(int $amountUzs, Percentage $percent): int
    {
        self::assertNotNegative($amountUzs);

        // amount = whole × 10000 + rest: whole × bp is already whole UZS, so
        // only the rest is rounded, and no product outgrows 64 bits.
        $whole = intdiv($amountUzs, self::BASIS);
        $rest = $amountUzs % self::BASIS;

        return $whole * $percent->basisPoints + self::divideHalfUp($rest * $percent->basisPoints, self::BASIS);
    }

    /**
     * The sum of UZS amounts, refused rather than turned into a float when it
     * would not fit a 64-bit integer.
     */
    public static function sum(int ...$amountsUzs): int
    {
        $total = 0;
        foreach ($amountsUzs as $amount) {
            self::assertNotNegative($amount);
            if ($total > PHP_INT_MAX - $amount) {
                throw new OverflowException('A UZS sum outgrew a 64-bit integer.');
            }
            $total += $amount;
        }

        return $total;
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
