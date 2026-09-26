<?php

declare(strict_types=1);

namespace Tests\Unit\Money;

use App\Support\Money\Percentage;
use InvalidArgumentException;
use PHPUnit\Framework\TestCase;

final class PercentageTest extends TestCase
{
    public function test_a_decimal_string_becomes_exact_basis_points(): void
    {
        $this->assertSame(0, Percentage::fromString('0')->basisPoints);
        $this->assertSame(1500, Percentage::fromString('15')->basisPoints);
        $this->assertSame(1250, Percentage::fromString('12.5')->basisPoints);
        $this->assertSame(1205, Percentage::fromString('12.05')->basisPoints);
        $this->assertSame(99_999, Percentage::fromString('999.99')->basisPoints);
    }

    public function test_it_always_leaves_with_two_decimals(): void
    {
        $this->assertSame('12.50', Percentage::fromString('12.5')->toDecimalString());
        $this->assertSame('0.00', Percentage::fromString('0')->toDecimalString());
        $this->assertSame('7.05', Percentage::fromBasisPoints(705)->toDecimalString());
    }

    public function test_anything_but_a_non_negative_two_place_decimal_is_refused(): void
    {
        foreach (['', '-1', '1.234', '1000', '12.', '.5', '1e2', '12,5', ' 12', "12\n", 'abc'] as $value) {
            try {
                Percentage::fromString($value);
                $this->fail('Accepted '.json_encode($value).'.');
            } catch (InvalidArgumentException) {
                $this->addToAssertionCount(1);
            }
        }
    }

    public function test_basis_points_outside_the_column_range_are_refused(): void
    {
        $this->expectException(InvalidArgumentException::class);

        Percentage::fromBasisPoints(100_000);
    }
}
