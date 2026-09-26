<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Requests\EmptyBodyRequest;
use App\Models\Product;
use App\Modules\Catalog\Actions\RemoveProductImage;
use App\Modules\Catalog\Actions\ReplaceProductImage;
use App\Modules\Catalog\Http\Requests\ProductImageRequest;
use App\Modules\Catalog\Http\Resources\AdminProductResource;
use App\Modules\Settings\CustomerPriceCalculator;
use App\Support\Scope\ScopedLookup;

/**
 * `POST|DELETE /admin/products/{product}/image` (`docs/09` section 16). Admin
 * only; the route declares it. Both answer the product with its current
 * `image_url`.
 */
final class AdminProductImageController extends Controller
{
    public function store(ProductImageRequest $request, string $product, ReplaceProductImage $replace): AdminProductResource
    {
        return $this->resource($replace($this->find($product), $request->uploadedImage(), $request->mimeType()));
    }

    public function destroy(EmptyBodyRequest $request, string $product, RemoveProductImage $remove): AdminProductResource
    {
        return $this->resource($remove($this->find($product)));
    }

    private function resource(Product $product): AdminProductResource
    {
        return new AdminProductResource($product, CustomerPriceCalculator::current());
    }

    private function find(string $id): Product
    {
        return ScopedLookup::firstOrNotFound(Product::query()->whereKey($id));
    }
}
