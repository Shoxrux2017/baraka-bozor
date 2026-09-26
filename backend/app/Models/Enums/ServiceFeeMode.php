<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * How the service fee of `BR-SET-001` is expressed: a fixed amount in UZS, or
 * a percentage of the merchandise subtotal (`BR-MONEY-005`).
 */
enum ServiceFeeMode: string
{
    case Fixed = 'fixed';
    case Percentage = 'percentage';
}
