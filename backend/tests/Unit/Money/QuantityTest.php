<?php

declare(strict_types=1);

namespace Tests\Unit\Money;

use App\Models\Enums\UnitCode;
use App\Modules\Orders\QuantityPolicy;
use App\Support\Money\MoneyCalculator;
use App\Support\Money\Quantity;
use Illuminate\Validation\ValidationException;
use InvalidArgumentException;
use Tests\TestCase;

/**
 * Quantities as exact thousandths, the line total of `BR-MONEY-003`, and the
 * per-unit rules of `BR-QTY-001` with the bounds of `DL-37` (6).
 */
final class QuantityTest extends TestCase
{
    public function test_a_quantity_is_read_and_written_exactly(): void
    {
        $this->assertSame(1500, Quantity::fromString('1.5')->thousandths);
        $this->assertSame(1250, Quantity::fromString('1.250')->thousandths);
        $this->assertSame(2000, Quantity::fromString('2')->thousandths);
        $this->assertSame('1.500', Quantity::fromString('1.5')->toDecimal());
        $this->assertSame('0.005', Quantity::fromString('0.005')->toDecimal());
        $this->assertSame('2', Quantity::fromString('2.000')->toWhole());
        $this->assertTrue(Quantity::fromString('3.000')->isWhole());
        $this->assertFalse(Quantity::fromString('3.001')->isWhole());
    }

    public function test_a_malformed_quantity_is_refused(): void
    {
        foreach (['-1', '1.2345', '1,5', '', ' 1', '1e3', '.5'] as $malformed) {
            try {
                Quantity::fromString($malformed);
                $this->fail("'{$malformed}' was accepted.");
            } catch (InvalidArgumentException) {
                $this->addToAssertionCount(1);
            }
        }
    }

    public function test_a_line_total_is_price_times_quantity_rounded_half_up(): void
    {
        $this->assertSame(27600, MoneyCalculator::lineTotal(18400, Quantity::fromString('1.5')));
        // 18 401 × 1.5 = 27 601.5 → 27 602; 18 401 × 0.001 = 18.401 → 18.
        $this->assertSame(27602, MoneyCalculator::lineTotal(18401, Quantity::fromString('1.5')));
        $this->assertSame(18, MoneyCalculator::lineTotal(18401, Quantity::fromString('0.001')));
        // The largest line the bounds allow stays exact.
        $this->assertSame(9_999_999_000_000, MoneyCalculator::lineTotal(1_000_000_000, Quantity::fromString('9999.999')));
    }

    public function test_the_units_that_take_a_fraction(): void
    {
        $fractional = array_values(array_filter(UnitCode::cases(), static fn (UnitCode $unit): bool => $unit->allowsFraction()));

        $this->assertSame([UnitCode::Kg, UnitCode::Liter, UnitCode::Meter], $fractional);
    }

    public function test_the_policy_formats_by_unit(): void
    {
        $this->assertSame('2', QuantityPolicy::format(UnitCode::Piece, '2.000'));
        $this->assertSame('2.000', QuantityPolicy::format(UnitCode::Kg, '2.000'));
        $this->assertSame('1.250', QuantityPolicy::parse(UnitCode::Liter, '1.25')->toDecimal());
        $this->expectException(ValidationException::class);
        QuantityPolicy::parse(UnitCode::Bundle, '1.5');
    }
}
