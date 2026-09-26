<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Http\Requests;

use App\Http\Requests\ListRequest;

/**
 * The Customer's category list takes only the page; archived and hidden
 * categories are never theirs to ask for.
 */
final class ListCustomerCategoriesRequest extends ListRequest
{
    /**
     * @return array<string, mixed>
     */
    protected function filters(): array
    {
        return [];
    }
}
