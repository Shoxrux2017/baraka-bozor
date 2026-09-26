<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * The two price modes of `DL-2` 2.2 and `01` Section 8: `fixed` guarantees the
 * customer price shown, `estimate` bills the actual market price plus the
 * markup, with the Customer's approval above the tolerance. Backed by the
 * strings `products_price_mode_check` lists.
 */
enum PriceMode: string
{
    case Fixed = 'fixed';
    case Estimate = 'estimate';
}
