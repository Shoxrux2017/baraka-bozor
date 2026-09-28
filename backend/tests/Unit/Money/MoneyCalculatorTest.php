<?php

declare(strict_types=1);

namespace Tests\Unit\Money;

use App\Support\Money\MoneyCalculator;
use App\Support\Money\Percentage;
use InvalidArgumentException;
use PHPUnit\Framework\TestCase;

/**
 * `BR-MONEY-003`: half up to 1 UZS, integer arithmetic only.
 */
final class MoneyCalculatorTest extends TestCase
{
    public function test_an_exact_result_is_not_rounded(): void
    {
        $this->assertSame(18_400, MoneyCalculator::increaseByPercent(16_000, Percentage::fromString('15')));
        $this->assertSame(16_000, MoneyCalculator::increaseByPercent(16_000, Percentage::fromString('0')));
    }

    public function test_exactly_half_a_sum_rounds_up(): void
    {
        // 5 × 1.10 = 5.5 → 6;  3 × 1.50 = 4.5 → 5;  1 × 1.50 = 1.5 → 2.
        $this->assertSame(6, MoneyCalculator::increaseByPercent(5, Percentage::fromString('10')));
        $this->assertSame(5, MoneyCalculator::increaseByPercent(3, Percentage::fromString('50')));
        $this->assertSame(2, MoneyCalculator::increaseByPercent(1, Percentage::fromString('50')));
    }

    public function test_just_below_and_just_above_the_half(): void
    {
        // 333 × 1.125 = 374.625 → 375;  333 × 1.12 = 372.96 → 373;  1001 × 1.0004 = 1001.4004 → 1001.
        $this->assertSame(375, MoneyCalculator::increaseByPercent(333, Percentage::fromString('12.5')));
        $this->assertSame(373, MoneyCalculator::increaseByPercent(333, Percentage::fromString('12')));
        $this->assertSame(1_001, MoneyCalculator::increaseByPercent(1_001, Percentage::fromString('0.04')));
    }

    public function test_a_hair_below_and_a_hair_above_the_half(): void
    {
        // 4999 × 1.0001 = 4999.4999 → 4999;  5001 × 1.0001 = 5001.5001 → 5002.
        $this->assertSame(4_999, MoneyCalculator::increaseByPercent(4_999, Percentage::fromString('0.01')));
        $this->assertSame(5_002, MoneyCalculator::increaseByPercent(5_001, Percentage::fromString('0.01')));
    }

    public function test_a_large_amount_stays_exact(): void
    {
        // 9 876 543 210 × 1.0001 = 9 877 530 864.321 → 9 877 530 864.
        $this->assertSame(9_877_530_864, MoneyCalculator::increaseByPercent(9_876_543_210, Percentage::fromString('0.01')));
    }

    public function test_a_negative_amount_is_refused(): void
    {
        $this->expectException(InvalidArgumentException::class);

        MoneyCalculator::increaseByPercent(-1, Percentage::fromString('10'));
    }

    public function test_the_largest_base_within_a_ceiling_is_the_last_one_that_stays_under_it(): void
    {
        // The estimate 18 400 plus 15 % tolerance is 21 160 to the Customer;
        // under a 15 % markup the stall may charge up to 18 400 (21 160), not
        // 18 401 (21 161.15 → 21 161).
        $this->assertSame(18_400, MoneyCalculator::largestBaseWithin(21_160, Percentage::fromString('15')));
        $this->assertSame(0, MoneyCalculator::largestBaseWithin(0, Percentage::fromString('15')));

        foreach (['0', '12.5', '15', '33.33', '999.99'] as $markup) {
            $percent = Percentage::fromString($markup);
            for ($ceiling = 1; $ceiling <= 3_000; $ceiling++) {
                $largest = MoneyCalculator::largestBaseWithin($ceiling, $percent);
                $this->assertLessThanOrEqual($ceiling, MoneyCalculator::increaseByPercent($largest, $percent), "{$ceiling} at {$markup} %");
                $this->assertGreaterThan($ceiling, MoneyCalculator::increaseByPercent($largest + 1, $percent), "{$ceiling} at {$markup} %: one more fits");
            }
        }

        $this->assertSame(10_000_000_000, MoneyCalculator::largestBaseWithin(10_000_000_000, Percentage::fromString('0')));
    }

    public function test_the_largest_base_within_refuses_a_negative_ceiling(): void
    {
        $this->expectException(InvalidArgumentException::class);

        MoneyCalculator::largestBaseWithin(-1, Percentage::fromString('15'));
    }
}
