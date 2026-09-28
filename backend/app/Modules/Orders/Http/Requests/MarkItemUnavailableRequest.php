<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\StrictFormRequest;

/**
 * A line the Shopper could not find (`docs/09` section 31): an optional note
 * of up to 300 characters, kept on the history row.
 */
final class MarkItemUnavailableRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'note' => ['sometimes', 'nullable', 'string', 'max:300'],
        ];
    }
}
