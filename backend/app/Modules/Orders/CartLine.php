<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\CartItem;
use App\Models\Product;

/**
 * One line of a `CartView`: the cart item, its product, and — only while the
 * Customer may see the product — its current customer price and the line's
 * estimate.
 */
final readonly class CartLine
{
    public function __construct(
        public CartItem $item,
        public Product $product,
        public bool $available,
        public ?int $customerUnitPriceUzs,
        public ?int $estimatedLineTotalUzs,
    ) {}
}
