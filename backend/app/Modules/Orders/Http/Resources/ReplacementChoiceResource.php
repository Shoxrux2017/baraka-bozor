<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Resources;

use App\Models\Product;
use App\Modules\Catalog\ProductImages;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A product the Shopper may offer as a replacement (`DL-54` (17)): its names,
 * unit, price mode, image and the market price the Shopper compares with the
 * stall — the Shopper judges by the market, not the Customer's price.
 *
 * @property-read Product $resource
 */
final class ReplacementChoiceResource extends JsonResource
{
    public function __construct(Product $product)
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
            'name_uz' => $product->name_uz,
            'name_ru' => $product->name_ru,
            'unit_code' => $product->unit_code->value,
            'price_mode' => $product->price_mode->value,
            'market_price_uzs' => $product->market_price_uzs,
            'image_url' => ProductImages::url($product->image),
        ];
    }
}
