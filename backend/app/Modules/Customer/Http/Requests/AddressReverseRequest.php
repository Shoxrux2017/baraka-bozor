<?php

declare(strict_types=1);

namespace App\Modules\Customer\Http\Requests;

use App\Http\Requests\StrictFormRequest;

/**
 * A point to name and the language to name it in (`DL-138` item 3). The
 * coordinates follow the address create rules: decimal strings, at most six
 * decimals.
 */
final class AddressReverseRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'latitude' => ['required', 'string', 'regex:/^-?\d{1,2}(\.\d{1,6})?\z/', 'numeric', 'between:-90,90'],
            'longitude' => ['required', 'string', 'regex:/^-?\d{1,3}(\.\d{1,6})?\z/', 'numeric', 'between:-180,180'],
            'language' => ['required', 'string', 'in:uz,ru'],
        ];
    }
}
