<?php

declare(strict_types=1);

namespace App\Modules\Staff\Http\Requests;

use App\Http\Requests\Concerns\RefusesEmptyPatch;
use App\Http\Requests\StrictFormRequest;

/**
 * An edit of a staff account (`docs/09` section 43): the name only. The role
 * never changes (`BR-ROLE-002`), and the phone is the login identity, so
 * either one in the body is an undeclared field.
 */
final class UpdateStaffRequest extends StrictFormRequest
{
    use RefusesEmptyPatch;

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'full_name' => ['sometimes', 'required', 'string', 'max:120'],
        ];
    }
}
