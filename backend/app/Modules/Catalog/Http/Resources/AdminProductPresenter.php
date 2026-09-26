<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Http\Resources;

use App\Models\Product;
use App\Modules\Settings\CustomerPriceCalculator;

/**
 * A product as the Admin panel sees it (`docs/09` section 15): the market
 * price the Admin entered and the customer price it becomes under the
 * current markup, side by side.
 *
 * The calculator is built once per response and passed in, so a page of a
 * hundred products reads the markup once.
 */
final class AdminProductPresenter
{
    public function __construct(private readonly CustomerPriceCalculator $prices) {}

    /**
     * @return array<string, mixed>
     */
    public function present(Product $product): array
    {
        return [
            'id' => $product->id,
            'category_id' => $product->category_id,
            'name_uz' => $product->name_uz,
            'name_ru' => $product->name_ru,
            'description_uz' => $product->description_uz,
            'description_ru' => $product->description_ru,
            'unit_code' => $product->unit_code->value,
            'price_mode' => $product->price_mode->value,
            'market_price_uzs' => $product->market_price_uzs,
            'customer_unit_price_uzs' => $this->prices->priceOf($product->market_price_uzs),
            'sort_order' => $product->sort_order,
            'is_active' => $product->is_active,
            'archived_at' => $product->archived_at?->toIso8601ZuluString(),
            'created_at' => $product->created_at->toIso8601ZuluString(),
            'updated_at' => $product->updated_at->toIso8601ZuluString(),
        ];
    }
}
