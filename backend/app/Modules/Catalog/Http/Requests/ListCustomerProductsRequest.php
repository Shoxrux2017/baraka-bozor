<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Http\Requests;

use App\Http\Requests\ListRequest;
use App\Modules\Catalog\CatalogSearch;
use App\Modules\Catalog\ProductSort;
use Illuminate\Validation\Rule;

final class ListCustomerProductsRequest extends ListRequest
{
    /**
     * @return array<string, mixed>
     */
    protected function filters(): array
    {
        return [
            'category_id' => ['sometimes', 'nullable', 'string', 'uuid'],
            'search' => ['sometimes', 'nullable', 'string', 'max:'.CatalogSearch::MAX_TERM_LENGTH],
            'featured' => ['sometimes', 'in:1,0,true,false'],
            'sort' => ['sometimes', Rule::enum(ProductSort::class)],
        ];
    }

    public function featuredOnly(): bool
    {
        return $this->boolean('featured');
    }

    public function sort(): ProductSort
    {
        return ProductSort::tryFrom((string) $this->query('sort', 'default')) ?? ProductSort::Default;
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
