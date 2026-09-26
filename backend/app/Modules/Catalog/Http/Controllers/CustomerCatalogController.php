<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Pagination\PaginatedResponse;
use App\Models\Category;
use App\Models\Product;
use App\Modules\Catalog\CustomerCatalogListing;
use App\Modules\Catalog\Http\Requests\ListCustomerCategoriesRequest;
use App\Modules\Catalog\Http\Requests\ListCustomerProductsRequest;
use App\Modules\Catalog\Http\Resources\CustomerCategoryResource;
use App\Modules\Catalog\Http\Resources\CustomerProductResource;
use App\Modules\Settings\CustomerPriceCalculator;
use App\Support\Scope\ScopedLookup;
use Illuminate\Http\JsonResponse;

/**
 * `GET /catalog/categories`, `GET /catalog/products`,
 * `GET /catalog/products/{product}` (`docs/09` section 14). A Customer session
 * is required (`DL-17` (4)); the route declares it.
 */
final class CustomerCatalogController extends Controller
{
    public function categories(ListCustomerCategoriesRequest $request): JsonResponse
    {
        return PaginatedResponse::of(
            CustomerCatalogListing::categories()->paginate($request->perPage(), ['*'], 'page', $request->page()),
            static fn (Category $category): array => (new CustomerCategoryResource($category))->resolve($request),
        );
    }

    public function products(ListCustomerProductsRequest $request): JsonResponse
    {
        $prices = CustomerPriceCalculator::current();

        return PaginatedResponse::of(
            CustomerCatalogListing::products($request->categoryId(), $request->search())
                ->paginate($request->perPage(), ['*'], 'page', $request->page()),
            static fn (Product $product): array => (new CustomerProductResource($product, $prices))->resolve($request),
        );
    }

    public function product(string $product): CustomerProductResource
    {
        $visible = CustomerCatalogListing::visibleProducts();

        return new CustomerProductResource(
            ScopedLookup::firstOrNotFound($visible->whereKey($product)),
            CustomerPriceCalculator::current(),
        );
    }
}
