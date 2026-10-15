<?php

declare(strict_types=1);

namespace App\Modules\Customer\Http\Resources;

use App\Models\Product;
use App\Modules\Catalog\Http\Resources\CustomerProductResource;
use App\Modules\Settings\CustomerPriceCalculator;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A favourite as the Customer's list shows it (`docs/09` section 58): the
 * Customer product object, `is_favorite` true, and `is_available`, which is
 * false once the product or its category is inactive or archived.
 *
 * @property-read Product $resource
 */
final class FavoriteProductResource extends JsonResource
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
        $category = $product->category;

        return [
            ...(new CustomerProductResource($product, $this->prices))->resolve($request),
            'is_favorite' => true,
            'is_available' => $product->is_active
                && $product->archived_at === null
                && $category->is_active
                && $category->archived_at === null,
        ];
    }
}
