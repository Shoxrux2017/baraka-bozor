<?php

declare(strict_types=1);

namespace App\Modules\Customer\Http\Requests;

use App\Http\Requests\ListRequest;

final class ListFavoritesRequest extends ListRequest
{
    /**
     * @return array<string, mixed>
     */
    protected function filters(): array
    {
        return [];
    }
}
