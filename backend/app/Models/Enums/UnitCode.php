<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * The units `01` Section 7 and `BR-QTY-001` approve, backed by the strings
 * `products_unit_code_check` lists.
 *
 * Which units take a fractional quantity is part of the unit, not of the
 * product: a kilogram of tomatoes may be 1.250 kg, a box may not be 1.25 boxes.
 */
enum UnitCode: string
{
    case Kg = 'kg';
    case Gram = 'gram';
    case Piece = 'piece';
    case Liter = 'liter';
    case Package = 'package';
    case Box = 'box';
    case Bundle = 'bundle';
    case Meter = 'meter';

    /**
     * Whether a quantity in this unit may carry up to three decimals; every
     * other unit takes a positive whole number.
     */
    public function acceptsDecimals(): bool
    {
        return match ($this) {
            self::Kg, self::Liter, self::Meter => true,
            self::Gram, self::Piece, self::Package, self::Box, self::Bundle => false,
        };
    }
}
