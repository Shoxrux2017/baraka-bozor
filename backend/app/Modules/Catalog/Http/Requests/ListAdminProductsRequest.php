<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Http\Requests;

use App\Http\Requests\ListRequest;
use App\Modules\Catalog\CatalogSearch;

final class ListAdminProductsRequest extends ListRequest
{
    /**
     * @return array<string, mixed>
     */
    protected function filters(): array
    {
        return [
            'include_archived' => ['sometimes', 'in:true,false,1,0'],
            'category_id' => ['sometimes', 'string', 'uuid'],
            'search' => ['sometimes', 'nullable', 'string', 'max:'.CatalogSearch::MAX_TERM_LENGTH],
        ];
    }

    public function includeArchived(): bool
    {
        return $this->flag('include_archived');
    }

    public function categoryId(): ?string
    {
        $id = $this->validated('category_id');

        return is_string($id) ? $id : null;
    }

    public function search(): ?string
    {
        $term = $this->validated('search');

        return is_string($term) ? $term : null;
    }
}
