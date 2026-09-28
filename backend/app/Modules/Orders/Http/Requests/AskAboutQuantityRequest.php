<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\StrictFormRequest;

/**
 * A smaller quantity to put to the Customer (`docs/09` section 34): a decimal
 * string, held to the line's unit and below the quantity billed by the
 * action, and an optional note.
 */
final class AskAboutQuantityRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'proposed_quantity' => ['required', 'string'],
            'note' => ['sometimes', 'nullable', 'string', 'max:300'],
        ];
    }
}
