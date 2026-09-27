<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\ListRequest;

/**
 * `GET /customer/orders`: the page and its size, no filters.
 */
final class ListCustomerOrdersRequest extends ListRequest
{
    /**
     * @return array<string, mixed>
     */
    protected function filters(): array
    {
        return [];
    }
}
