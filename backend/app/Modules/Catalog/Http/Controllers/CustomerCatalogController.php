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
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

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
            $this->withFavoriteFlag(
                CustomerCatalogListing::products($request->categoryId(), $request->search(), $request->featuredOnly(), $request->sort()),
                $request,
            )->paginate($request->perPage(), ['*'], 'page', $request->page()),
            static fn (Product $product): array => (new CustomerProductResource($product, $prices))->resolve($request),
        );
    }

    public function product(Request $request, string $product): CustomerProductResource
    {
        $visible = $this->withFavoriteFlag(CustomerCatalogListing::visibleProducts(), $request);

        return new CustomerProductResource(
            ScopedLookup::firstOrNotFound($visible->whereKey($product)),
            CustomerPriceCalculator::current(),
        );
    }

    /**
     * The `is_favorite` flag of the session's Customer. It is added here and
     * not inside `visibleProducts()`, which the cart locks with `FOR UPDATE`.
     *
     * @param  Builder<Product>  $query
     * @return Builder<Product>
     */
    private function withFavoriteFlag(Builder $query, Request $request): Builder
    {
        $customerId = $request->user()?->getAuthIdentifier();

        return $query->withExists(['favorites as is_favorite' => static function (Builder $favorite) use ($customerId): void {
            $favorite->where('customer_id', $customerId);
        }]);
    }
}
