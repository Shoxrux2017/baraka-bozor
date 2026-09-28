<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\StrictFormRequest;

/**
 * The Customer's decision on a question (`docs/09` section 23): approve or
 * reject, nothing else.
 */
final class DecideApprovalRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'decision' => ['required', 'string', 'in:approve,reject'],
        ];
    }
}
