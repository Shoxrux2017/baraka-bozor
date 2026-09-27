<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\Cart;
use App\Modules\Catalog\CustomerCatalogListing;
use App\Modules\Settings\CustomerPriceCalculator;
use App\Support\Money\MoneyCalculator;
use App\Support\Money\Quantity;

/**
 * The cart as it stands for the Customer (`BR-CART-003`, `DL-37` (20)): each
 * line with its product, whether the Customer may still see that product, its
 * current customer price and the line's estimate, and the estimate subtotal
 * over the available lines. The resource only formats this; checkout reads
 * the same lines.
 *
 * Four queries whatever the cart's size: the lines, their products, the
 * products' images, and which of the products are still visible.
 */
final readonly class CartView
{
    /**
     * @param  list<CartLine>  $lines
     */
    private function __construct(
        public Cart $cart,
        public array $lines,
        public int $estimatedSubtotalUzs,
    ) {}

    public static function of(Cart $cart, CustomerPriceCalculator $prices): self
    {
        $items = $cart->items()->with('product.image')->orderBy('created_at')->orderBy('id')->get();

        $visible = CustomerCatalogListing::visibleProducts()
            ->without('image')
            ->whereIn('id', $items->pluck('product_id')->all())
            ->pluck('id')
            ->flip();

        $lines = [];
        $subtotal = 0;

        foreach ($items as $item) {
            $available = $visible->has($item->product_id);
            $price = $available ? $prices->priceOf($item->product->market_price_uzs) : null;
            $estimate = $price === null ? null : MoneyCalculator::lineTotal($price, Quantity::fromString($item->quantity));

            $lines[] = new CartLine($item, $item->product, $available, $price, $estimate);
            $subtotal += $estimate ?? 0;
        }

        return new self($cart, $lines, $subtotal);
    }
}
