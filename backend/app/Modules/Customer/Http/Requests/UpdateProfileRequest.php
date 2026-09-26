<?php

declare(strict_types=1);

namespace App\Modules\Customer\Http\Requests;

use App\Http\Requests\Concerns\RefusesEmptyPatch;
use App\Http\Requests\StrictFormRequest;

/**
 * The Customer's profile (`docs/09` section 12): the name checkout will
 * require (`BR-CHK-001`) and the language push texts use. The phone is the
 * login identity and is not edited here (`docs/03` section 3). A name is
 * trimmed by the framework and must then hold 1 to 120 characters — the same
 * rule as a staff name.
 */
final class UpdateProfileRequest extends StrictFormRequest
{
    use RefusesEmptyPatch;

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'full_name' => ['sometimes', 'required', 'string', 'max:120'],
            'preferred_language' => ['sometimes', 'required', 'string', 'in:uz,ru'],
        ];
    }
}
