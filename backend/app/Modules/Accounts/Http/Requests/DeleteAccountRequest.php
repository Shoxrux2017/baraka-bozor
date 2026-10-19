<?php

declare(strict_types=1);

namespace App\Modules\Accounts\Http\Requests;

use App\Http\Requests\StrictFormRequest;
use App\Modules\Auth\LoginCodePolicy;

final class DeleteAccountRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'code' => ['required', 'string', 'regex:'.LoginCodePolicy::CODE_PATTERN],
        ];
    }
}
