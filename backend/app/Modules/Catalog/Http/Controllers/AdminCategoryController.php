<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Pagination\PaginatedResponse;
use App\Models\Category;
use App\Models\User;
use App\Modules\Catalog\Actions\CatalogArchive;
use App\Modules\Catalog\Actions\SaveCatalogEntry;
use App\Modules\Catalog\AdminCatalogListing;
use App\Modules\Catalog\Http\Requests\CategoryRequest;
use App\Modules\Catalog\Http\Requests\ListCategoriesRequest;
use App\Modules\Catalog\Http\Resources\AdminCategoryResource;
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
        return PaginatedResponse::of(
            AdminCatalogListing::categories($request->includeArchived())
                ->paginate($request->perPage(), ['*'], 'page', $request->page()),
            static fn (Category $category): array => (new AdminCategoryResource($category))->resolve($request),
        );
    }

    public function store(CategoryRequest $request, SaveCatalogEntry $save): JsonResponse
    {
        /** @var array<string, mixed> $fields */
        $fields = $request->validated();

        return (new AdminCategoryResource($save->createCategory($this->admin($request), $fields)))
            ->response()
            ->setStatusCode(201);
    }

    public function show(string $category): AdminCategoryResource
    {
        return new AdminCategoryResource($this->find($category));
    }

    public function update(CategoryRequest $request, string $category, SaveCatalogEntry $save): AdminCategoryResource
    {
        /** @var array<string, mixed> $fields */
        $fields = $request->validated();

        return new AdminCategoryResource($save->updateCategory($this->find($category), $fields));
    }

    public function archive(string $category, CatalogArchive $archive): AdminCategoryResource
    {
        return new AdminCategoryResource($archive->archiveCategory($this->find($category)));
    }

    public function restore(string $category, CatalogArchive $archive): AdminCategoryResource
    {
        return new AdminCategoryResource($archive->restoreCategory($this->find($category)));
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
