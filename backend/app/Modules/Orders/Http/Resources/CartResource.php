<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Resources;

use App\Models\Cart;
use App\Models\CartItem;
use App\Modules\Catalog\CustomerCatalogListing;
use App\Modules\Catalog\ProductImages;
use App\Modules\Orders\QuantityPolicy;
use App\Modules\Settings\CustomerPriceCalculator;
use App\Support\Money\MoneyCalculator;
use App\Support\Money\Quantity;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * The cart as the Customer sees it (`docs/09` section 17, `BR-CART-003`):
 * current customer prices, never the market price, and an estimate per line
 * and for the whole cart. A line whose product the Customer may no longer see
 * stays, marked `is_available: false`, with no price and outside the subtotal
 * (`DL-37` (20)), so the Customer sees why checkout will refuse it. The
 * client shows these amounts and never sums prices itself (`DL-37` (19)).
 *
 * @property-read Cart $resource
 */
final class CartResource extends JsonResource
{
    public function __construct(Cart $cart, private readonly CustomerPriceCalculator $prices)
    {
        parent::__construct($cart);
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $items = $this->resource->items()->with('product.image')->orderBy('created_at')->orderBy('id')->get();

        $visible = CustomerCatalogListing::visibleProducts()
            ->whereIn('id', $items->pluck('product_id')->all())
            ->pluck('id')
            ->flip();

        $subtotal = 0;
        $lines = [];

        foreach ($items as $item) {
            $line = $this->line($item, $visible->has($item->product_id));
            $subtotal += $line['estimated_line_total_uzs'] ?? 0;
            $lines[] = $line;
        }

        return [
            'id' => $this->resource->id,
            'items' => $lines,
            'item_count' => count($lines),
            'estimated_subtotal_uzs' => $subtotal,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function line(CartItem $item, bool $available): array
    {
        $product = $item->product;
        $price = $available ? $this->prices->priceOf($product->market_price_uzs) : null;

        return [
            'id' => $item->id,
            'product_id' => $product->id,
            'name_uz' => $product->name_uz,
            'name_ru' => $product->name_ru,
            'unit_code' => $product->unit_code->value,
            'price_mode' => $product->price_mode->value,
            'image_url' => ProductImages::url($product->image),
            'quantity' => QuantityPolicy::format($product->unit_code, $item->quantity),
            'customer_note' => $item->customer_note,
            'substitution_policy' => $item->substitution_policy->value,
            'is_available' => $available,
            'customer_unit_price_uzs' => $price,
            'estimated_line_total_uzs' => $price === null
                ? null
                : MoneyCalculator::lineTotal($price, Quantity::fromString($item->quantity)),
        ];
    }
}
