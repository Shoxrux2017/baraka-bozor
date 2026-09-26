<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Pagination\PaginatedResponse;
use App\Models\Category;
use App\Models\User;
use App\Modules\Catalog\Actions\CatalogArchive;
use App\Modules\Catalog\Actions\SaveCatalogEntry;
use App\Modules\Catalog\CatalogSearch;
use App\Modules\Catalog\Http\Requests\CategoryRequest;
use App\Modules\Catalog\Http\Requests\ListCategoriesRequest;
use App\Modules\Catalog\Http\Resources\AdminCategoryPresenter;
use App\Support\Scope\ScopedLookup;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * `/admin/categories` (`docs/09` section 15). Admin only; the route declares
 * it. An Admin sees every category, so the lookup is by id alone and a
 * missing one is the scope-safe `404`.
 */
final class AdminCategoryController extends Controller
{
    public function index(ListCategoriesRequest $request): JsonResponse
    {
        $query = CatalogSearch::ordered(Category::query());

        if (! $request->includeArchived()) {
            $query->whereNull('archived_at');
        }

        return PaginatedResponse::of(
            $query->paginate($request->perPage(), ['*'], 'page', $request->page()),
            static fn (Category $category): array => AdminCategoryPresenter::present($category),
        );
    }

    public function store(CategoryRequest $request, SaveCatalogEntry $save): JsonResponse
    {
        /** @var array<string, mixed> $fields */
        $fields = $request->validated();

        return new JsonResponse(
            ['data' => AdminCategoryPresenter::present($save->createCategory($this->admin($request), $fields))],
            201,
        );
    }

    public function show(string $category): JsonResponse
    {
        return new JsonResponse(['data' => AdminCategoryPresenter::present($this->find($category))]);
    }

    public function update(CategoryRequest $request, string $category, SaveCatalogEntry $save): JsonResponse
    {
        /** @var array<string, mixed> $fields */
        $fields = $request->validated();

        /** @var Category $saved */
        $saved = $save->update($this->find($category), $fields);

        return new JsonResponse(['data' => AdminCategoryPresenter::present($saved)]);
    }

    public function archive(string $category, CatalogArchive $archive): JsonResponse
    {
        /** @var Category $archived */
        $archived = $archive->archive($this->find($category));

        return new JsonResponse(['data' => AdminCategoryPresenter::present($archived)]);
    }

    public function restore(string $category, CatalogArchive $archive): JsonResponse
    {
        /** @var Category $restored */
        $restored = $archive->restore($this->find($category));

        return new JsonResponse(['data' => AdminCategoryPresenter::present($restored)]);
    }

    private function find(string $id): Category
    {
        return ScopedLookup::firstOrNotFound(Category::query()->whereKey($id));
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
