<?php

declare(strict_types=1);

namespace App\Modules\Catalog;

/**
 * How a Customer's product list is ordered (`docs/09` section 14, `DL-79`).
 * Popularity is not offered: no figures exist before the pilot.
 */
enum ProductSort: string
{
    case Default = 'default';
    case PriceAsc = 'price_asc';
    case PriceDesc = 'price_desc';
}
