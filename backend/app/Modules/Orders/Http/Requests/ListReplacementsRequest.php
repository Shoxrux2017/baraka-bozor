<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\ListRequest;
use App\Modules\Catalog\CatalogSearch;

/**
 * `GET /shopper/orders/{order}/items/{item}/replacements`: the page, its size
 * and a search term of up to 100 characters (`DL-54` (17)).
 */
final class ListReplacementsRequest extends ListRequest
{
    /**
     * @return array<string, mixed>
     */
    protected function filters(): array
    {
        return [
            'search' => ['sometimes', 'nullable', 'string', 'max:'.CatalogSearch::MAX_TERM_LENGTH],
        ];
    }

    public function search(): ?string
    {
        return $this->text('search');
    }
}
