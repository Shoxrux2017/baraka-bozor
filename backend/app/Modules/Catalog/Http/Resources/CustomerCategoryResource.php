<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Http\Resources;

use App\Models\Category;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A category as the Customer sees it (`docs/09` section 14): its names and
 * descriptions in both languages, and its place in the list. Nothing about
 * who created it or when.
 *
 * @property-read Category $resource
 */
final class CustomerCategoryResource extends JsonResource
{
    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->resource->id,
            'name_uz' => $this->resource->name_uz,
            'name_ru' => $this->resource->name_ru,
            'description_uz' => $this->resource->description_uz,
            'description_ru' => $this->resource->description_ru,
            'sort_order' => $this->resource->sort_order,
        ];
    }
}
