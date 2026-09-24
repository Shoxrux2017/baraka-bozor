<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Requests;

use App\Http\Requests\StrictFormRequest;

final class StaffLoginRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            // Uzbekistan mobile E.164, `docs/09-api-contracts.md` Section 6.
            'phone' => ['required', 'string', 'regex:/^\+998[0-9]{9}$/'],
            'password' => ['required', 'string', 'max:128'],
        ];
    }
}
