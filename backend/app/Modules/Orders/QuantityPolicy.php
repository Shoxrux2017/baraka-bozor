<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\Enums\UnitCode;
use App\Support\Money\Quantity;
use Illuminate\Validation\ValidationException;

/**
 * What a quantity may be for a unit (`BR-QTY-001`, `DL-37` (6)): `kg`, `liter`
 * and `meter` take a positive decimal string with at most three decimals, the
 * other units a positive whole number written without a fraction; neither goes
 * above 9 999.999 or 9 999. The bound is a technical ceiling no household
 * order reaches, and it keeps every line total far inside the integer range.
 *
 * A refusal is `422 validation_failed` on the field that carried the value, so
 * the client shows it where the Customer typed it.
 */
final class QuantityPolicy
{
    private const DECIMAL = '/^\d{1,4}(\.\d{1,3})?\z/';

    private const WHOLE = '/^\d{1,4}\z/';

    public static function parse(UnitCode $unit, mixed $value, string $field = 'quantity'): Quantity
    {
        $pattern = $unit->allowsFraction() ? self::DECIMAL : self::WHOLE;

        if (! is_string($value) || preg_match($pattern, $value) !== 1) {
            throw ValidationException::withMessages([$field => $unit->allowsFraction()
                ? 'A quantity of this unit has at most four digits and three decimals.'
                : 'A quantity of this unit is a whole number of at most four digits.',
            ]);
        }

        $quantity = Quantity::fromString($value);

        if ($quantity->thousandths === 0) {
            throw ValidationException::withMessages([$field => 'A quantity is positive.']);
        }

        return $quantity;
    }

    /**
     * How the API shows a stored quantity: three decimals for a unit that takes
     * a fraction (`"1.500"`), a whole number for the others (`"2"`).
     */
    public static function format(UnitCode $unit, string $stored): string
    {
        $quantity = Quantity::fromString($stored);

        return $unit->allowsFraction() || ! $quantity->isWhole() ? $quantity->toDecimal() : $quantity->toWhole();
    }
}
