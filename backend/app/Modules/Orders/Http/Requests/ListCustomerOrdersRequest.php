<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\ListRequest;
use Illuminate\Validation\Rule;

/**
 * `GET /customer/orders`: the page and its size, and the `state` tab —
 * `current` or `past` (`DL-91` (1)).
 */
final class ListCustomerOrdersRequest extends ListRequest
{
    /**
     * @return array<string, mixed>
     */
    protected function filters(): array
    {
        return [
            'state' => ['sometimes', 'nullable', 'string', Rule::in(['current', 'past'])],
        ];
    }

    public function state(): ?string
    {
        return $this->text('state');
    }
}
