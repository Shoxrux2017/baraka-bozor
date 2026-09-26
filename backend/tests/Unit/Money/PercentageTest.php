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

    public function test_leading_zeros_are_read_as_the_number_they_write(): void
    {
        $this->assertSame(700, Percentage::fromString('007')->basisPoints);
        $this->assertSame(5, Percentage::fromString('0.05')->basisPoints);
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
}
