<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Pagination\PaginatedResponse;
use App\Models\Product;
use App\Models\User;
use App\Modules\Catalog\Actions\CatalogArchive;
use App\Modules\Catalog\Actions\SaveCatalogEntry;
use App\Modules\Catalog\CatalogSearch;
use App\Modules\Catalog\Http\Requests\ListAdminProductsRequest;
use App\Modules\Catalog\Http\Requests\ProductRequest;
use App\Modules\Catalog\Http\Resources\AdminProductPresenter;
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
        $query = CatalogSearch::ordered(CatalogSearch::matching(Product::query(), $request->search()));

        if (! $request->includeArchived()) {
            $query->whereNull('archived_at');
        }

        $categoryId = $request->categoryId();
        if ($categoryId !== null) {
            $query->where('category_id', $categoryId);
        }

        $presenter = new AdminProductPresenter(CustomerPriceCalculator::current());

        return PaginatedResponse::of(
            $query->paginate($request->perPage(), ['*'], 'page', $request->page()),
            static fn (Product $product): array => $presenter->present($product),
        );
    }

    public function store(ProductRequest $request, SaveCatalogEntry $save): JsonResponse
    {
        /** @var array<string, mixed> $fields */
        $fields = $request->validated();

        return new JsonResponse(
            ['data' => $this->presenter()->present($save->createProduct($this->admin($request), $fields))],
            201,
        );
    }

    public function show(string $product): JsonResponse
    {
        return new JsonResponse(['data' => $this->presenter()->present($this->find($product))]);
    }

    public function update(ProductRequest $request, string $product, SaveCatalogEntry $save): JsonResponse
    {
        /** @var array<string, mixed> $fields */
        $fields = $request->validated();

        /** @var Product $saved */
        $saved = $save->update($this->find($product), $fields);

        return new JsonResponse(['data' => $this->presenter()->present($saved)]);
    }

    public function archive(string $product, CatalogArchive $archive): JsonResponse
    {
        /** @var Product $archived */
        $archived = $archive->archive($this->find($product));

        return new JsonResponse(['data' => $this->presenter()->present($archived)]);
    }

    public function restore(string $product, CatalogArchive $archive): JsonResponse
    {
        /** @var Product $restored */
        $restored = $archive->restore($this->find($product));

        return new JsonResponse(['data' => $this->presenter()->present($restored)]);
    }

    private function presenter(): AdminProductPresenter
    {
        return new AdminProductPresenter(CustomerPriceCalculator::current());
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
