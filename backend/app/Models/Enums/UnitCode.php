<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * The units `01` Section 7 and `BR-QTY-001` approve, backed by the strings
 * `products_unit_code_check` lists.
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
     * `kg`, `liter` and `meter` take up to three decimals; the others are
     * counted in whole units (`BR-QTY-001`).
     */
    public function allowsFraction(): bool
    {
        return match ($this) {
            self::Kg, self::Liter, self::Meter => true,
            default => false,
        };
    }
}
