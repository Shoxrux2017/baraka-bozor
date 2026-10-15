<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Requests\EmptyBodyRequest;
use App\Models\Category;
use App\Modules\Catalog\Actions\RemoveCategoryImage;
use App\Modules\Catalog\Actions\ReplaceCategoryImage;
use App\Modules\Catalog\Http\Requests\CatalogImageRequest;
use App\Modules\Catalog\Http\Resources\AdminCategoryResource;
use App\Support\Scope\ScopedLookup;

/**
 * `POST|DELETE /admin/categories/{category}/image` (`docs/09` section 16).
 * Admin only; the route declares it. Both answer the category with its
 * current `image_url`.
 */
final class AdminCategoryImageController extends Controller
{
    public function store(CatalogImageRequest $request, string $category, ReplaceCategoryImage $replace): AdminCategoryResource
    {
        return new AdminCategoryResource($replace($this->find($category), $request->uploadedImage(), $request->mimeType()));
    }

    public function destroy(EmptyBodyRequest $request, string $category, RemoveCategoryImage $remove): AdminCategoryResource
    {
        return new AdminCategoryResource($remove($this->find($category)));
    }

    private function find(string $id): Category
    {
        return ScopedLookup::firstOrNotFound(Category::query()->whereKey($id));
    }
}
