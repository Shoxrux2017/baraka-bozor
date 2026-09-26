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
            'include_archived' => ['sometimes', 'nullable', 'in:true,false,1,0'],
            'category_id' => ['sometimes', 'nullable', 'string', 'uuid'],
            'search' => ['sometimes', 'nullable', 'string', 'max:'.CatalogSearch::MAX_TERM_LENGTH],
        ];
    }

    public function includeArchived(): bool
    {
        return $this->flag('include_archived');
    }

    public function categoryId(): ?string
    {
        return $this->text('category_id');
    }

    public function search(): ?string
    {
        return $this->text('search');
    }
}
