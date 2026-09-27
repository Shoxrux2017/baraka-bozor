<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Resources;

use App\Modules\Catalog\ProductImages;
use App\Modules\Orders\CartLine;
use App\Modules\Orders\CartView;
use App\Modules\Orders\QuantityPolicy;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * The cart as the Customer sees it (`docs/09` section 17): current customer
 * prices, never the market price, and an estimate per line and for the whole
 * cart, as `CartView` computed them. A line whose product the Customer may no
 * longer see stays, marked `is_available: false`, with no price (`DL-37`
 * (20)). The client shows these amounts and never sums prices itself
 * (`DL-37` (19)).
 *
 * @property-read CartView $resource
 */
final class CartResource extends JsonResource
{
    public function __construct(CartView $view)
    {
        parent::__construct($view);
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $view = $this->resource;

        return [
            'id' => $view->cart->id,
            'items' => array_map($this->line(...), $view->lines),
            'item_count' => count($view->lines),
            'estimated_subtotal_uzs' => $view->estimatedSubtotalUzs,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function line(CartLine $line): array
    {
        return [
            'id' => $line->item->id,
            'product_id' => $line->product->id,
            'name_uz' => $line->product->name_uz,
            'name_ru' => $line->product->name_ru,
            'unit_code' => $line->product->unit_code->value,
            'price_mode' => $line->product->price_mode->value,
            'image_url' => ProductImages::url($line->product->image),
            'quantity' => QuantityPolicy::format($line->product->unit_code, $line->item->quantity),
            'customer_note' => $line->item->customer_note,
            'substitution_policy' => $line->item->substitution_policy->value,
            'is_available' => $line->available,
            'customer_unit_price_uzs' => $line->customerUnitPriceUzs,
            'estimated_line_total_uzs' => $line->estimatedLineTotalUzs,
        ];
    }
}
