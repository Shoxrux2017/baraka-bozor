<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\ListRequest;

/**
 * `GET /operations/shoppers` and `GET /operations/couriers` (`DL-37` (11)):
 * the page alone.
 */
final class ListStaffChoicesRequest extends ListRequest
{
    /**
     * @return array<string, mixed>
     */
    protected function filters(): array
    {
        return [];
    }
}
