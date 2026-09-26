<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * The units `01` Section 7 and `BR-QTY-001` approve, backed by the strings
 * `products_unit_code_check` lists. Which of them take a fractional quantity
 * is the cart's concern and arrives with it (Wave 2).
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
}
