<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\Concerns\RefusesEmptyPatch;
use App\Http\Requests\StrictFormRequest;
use App\Models\Enums\SubstitutionPolicy;
use Illuminate\Validation\Rule;

/**
 * A change to a cart line (`docs/09` section 17): any non-empty subset of the
 * quantity, the note and the rule. The product is not changed; a different
 * product is a different line.
 */
final class UpdateCartItemRequest extends StrictFormRequest
{
    use RefusesEmptyPatch;

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'quantity' => ['sometimes', 'required', 'string'],
            'customer_note' => ['sometimes', 'nullable', 'string', 'max:300'],
            'substitution_policy' => ['sometimes', 'required', 'string', Rule::enum(SubstitutionPolicy::class)],
        ];
    }
}
