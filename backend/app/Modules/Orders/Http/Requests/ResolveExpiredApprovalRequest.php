<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\StrictFormRequest;

/**
 * The Operator's resolution of an expired approval (`docs/09` section 40):
 * `remove_item`, the only one there is (`BR-APP-007`), and an optional note
 * of up to 300 characters.
 */
final class ResolveExpiredApprovalRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'resolution' => ['required', 'string', 'in:remove_item'],
            'note' => ['sometimes', 'nullable', 'string', 'max:300'],
        ];
    }
}
