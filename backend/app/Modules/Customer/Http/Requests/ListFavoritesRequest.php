<?php

declare(strict_types=1);

namespace App\Modules\Customer\Http\Requests;

use App\Http\Requests\ListRequest;
use App\Modules\Catalog\ProductSort;
use Illuminate\Validation\Rule;

final class ListFavoritesRequest extends ListRequest
{
    /**
     * @return array<string, mixed>
     */
    protected function filters(): array
    {
        return ['sort' => ['sometimes', Rule::enum(ProductSort::class)]];
    }

    public function sort(): ProductSort
    {
        return ProductSort::tryFrom((string) $this->query('sort', 'default')) ?? ProductSort::Default;
    }
}
