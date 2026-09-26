<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Http\Resources;

use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A category as the Admin panel sees it (`docs/09` section 15). The creator
 * is recorded but not shown.
 *
 * @property-read Category $resource
 */
final class AdminCategoryResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $category = $this->resource;

        return [
            'id' => $category->id,
            'name_uz' => $category->name_uz,
            'name_ru' => $category->name_ru,
            'description_uz' => $category->description_uz,
            'description_ru' => $category->description_ru,
            'sort_order' => $category->sort_order,
            'is_active' => $category->is_active,
            'archived_at' => $category->archived_at?->toIso8601ZuluString(),
            'created_at' => $category->created_at->toIso8601ZuluString(),
            'updated_at' => $category->updated_at->toIso8601ZuluString(),
        ];
    }
}
