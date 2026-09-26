<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Pagination\PaginatedResponse;
use App\Models\Product;
use App\Models\User;
use App\Modules\Catalog\Actions\CatalogArchive;
use App\Modules\Catalog\Actions\SaveCatalogEntry;
use App\Modules\Catalog\AdminCatalogListing;
use App\Modules\Catalog\Http\Requests\ListAdminProductsRequest;
use App\Modules\Catalog\Http\Requests\ProductRequest;
use App\Modules\Catalog\Http\Resources\AdminProductResource;
use App\Modules\Settings\CustomerPriceCalculator;
use App\Support\Scope\ScopedLookup;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * `/admin/products` (`docs/09` section 15). Admin only; the route declares
 * it. The list takes the category and search filters the panel's product
 * table needs, so no second API change is due when the panel lands.
 */
final class AdminProductController extends Controller
{
    public function index(ListAdminProductsRequest $request): JsonResponse
    {
        $prices = CustomerPriceCalculator::current();

        return PaginatedResponse::of(
            AdminCatalogListing::products($request->includeArchived(), $request->categoryId(), $request->search())
                ->paginate($request->perPage(), ['*'], 'page', $request->page()),
            static fn (Product $product): array => (new AdminProductResource($product, $prices))->resolve($request),
        );
    }

    public function store(ProductRequest $request, SaveCatalogEntry $save): JsonResponse
    {
        /** @var array<string, mixed> $fields */
        $fields = $request->validated();

        return $this->resource($save->createProduct($this->admin($request), $fields))
            ->response()
            ->setStatusCode(201);
    }

    public function show(string $product): AdminProductResource
    {
        return $this->resource($this->find($product));
    }

    public function update(ProductRequest $request, string $product, SaveCatalogEntry $save): AdminProductResource
    {
        /** @var array<string, mixed> $fields */
        $fields = $request->validated();

        return $this->resource($save->updateProduct($this->find($product), $fields));
    }

    public function archive(string $product, CatalogArchive $archive): AdminProductResource
    {
        return $this->resource($archive->archiveProduct($this->find($product)));
    }

    public function restore(string $product, CatalogArchive $archive): AdminProductResource
    {
        return $this->resource($archive->restoreProduct($this->find($product)));
    }

    private function resource(Product $product): AdminProductResource
    {
        return new AdminProductResource($product, CustomerPriceCalculator::current());
    }

    private function find(string $id): Product
    {
        return ScopedLookup::firstOrNotFound(Product::query()->whereKey($id));
    }

    private function admin(Request $request): User
    {
        $user = $request->user();

        if (! $user instanceof User) {
            abort(401);
        }

        return $user;
    }
}
