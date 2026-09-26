<?php

declare(strict_types=1);

namespace App\Modules\Customer\Http\Requests;

use App\Http\Requests\Concerns\RefusesEmptyPatch;
use App\Http\Requests\StrictFormRequest;

/**
 * A delivery address (`docs/09` section 13, `docs/08` section 5). The point,
 * the street and the house are required on create; the label, apartment,
 * landmark and note are optional; an update takes any non-empty subset, and
 * the two coordinates always travel together, because half a point is no
 * point. Coordinates are decimal strings with at most six decimals, as the
 * columns hold them. Lengths fit the columns (`DL-23`).
 */
final class AddressRequest extends StrictFormRequest
{
    use RefusesEmptyPatch;

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $creating = $this->isMethod('POST');
        $presence = $creating ? 'required' : 'sometimes';

        // On an update neither coordinate is required, but each requires the
        // other; `sometimes` would skip the absent one and let half a point in.
        return [
            'latitude' => [
                $creating ? 'required' : 'required_with:longitude', 'string',
                'regex:/^-?\d{1,2}(\.\d{1,6})?\z/', 'numeric', 'between:-90,90',
            ],
            'longitude' => [
                $creating ? 'required' : 'required_with:latitude', 'string',
                'regex:/^-?\d{1,3}(\.\d{1,6})?\z/', 'numeric', 'between:-180,180',
            ],
            'street' => [$presence, 'required', 'string', 'max:160'],
            'house' => [$presence, 'required', 'string', 'max:40'],
            'label' => ['sometimes', 'nullable', 'string', 'max:60'],
            'apartment' => ['sometimes', 'nullable', 'string', 'max:40'],
            'landmark' => ['sometimes', 'nullable', 'string', 'max:160'],
            'delivery_note' => ['sometimes', 'nullable', 'string', 'max:300'],
        ];
    }
}
