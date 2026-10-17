<?php

declare(strict_types=1);

namespace App\Modules\Customer\Http\Requests;

use App\Http\Requests\StrictFormRequest;

/**
 * The words of an address to look up: 3 to 200 characters once trimmed.
 */
final class AddressSearchRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'query' => ['required', 'string', 'min:3', 'max:200'],
        ];
    }
}
