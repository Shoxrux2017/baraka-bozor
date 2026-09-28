<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * The kinds of question a Shopper puts to the Customer (`08` Section 18,
 * `BR-APP` of `05` Section 12).
 */
enum ApprovalType: string
{
    case PriceOverTolerance = 'price_over_tolerance';
    case Substitution = 'substitution';
    case ReducedQuantity = 'reduced_quantity';
}
