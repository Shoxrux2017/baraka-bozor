<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Http\Resources;

use App\Models\Product;
use App\Modules\Catalog\ProductImages;
use App\Modules\Settings\CustomerPriceCalculator;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A product as the Customer sees it (`docs/09` section 14): the customer
 * price and never the market price (`BR-PRICE-001`: the Customer only ever
 * sees customer prices). `price_mode` tells the client whether the price is
 * guaranteed (`fixed`) or an estimate.
 *
 * @property-read Product $resource
 */
final class CustomerProductResource extends JsonResource
{
    public function __construct(Product $product, private readonly CustomerPriceCalculator $prices)
    {
        parent::__construct($product);
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $product = $this->resource;

        return [
            'id' => $product->id,
            'category_id' => $product->category_id,
            'name_uz' => $product->name_uz,
            'name_ru' => $product->name_ru,
            'description_uz' => $product->description_uz,
            'description_ru' => $product->description_ru,
            'unit_code' => $product->unit_code->value,
            'price_mode' => $product->price_mode->value,
            'customer_unit_price_uzs' => $this->prices->priceOf($product->market_price_uzs),
            'image_url' => ProductImages::url($product->image),
            'is_active' => $product->is_active,
        ];
    }
}
