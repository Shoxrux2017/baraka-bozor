<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Http\Requests;

use App\Http\Requests\ListRequest;

final class ListCategoriesRequest extends ListRequest
{
    /**
     * @return array<string, mixed>
     */
    protected function filters(): array
    {
        return [
            'include_archived' => ['sometimes', 'nullable', 'in:true,false,1,0'],
        ];
    }

    public function includeArchived(): bool
    {
        return $this->flag('include_archived');
    }
}
