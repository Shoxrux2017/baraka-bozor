<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Requests;

use App\Http\Requests\StrictFormRequest;

/**
 * `new_password` is validated here, before the action checks
 * `current_password`, so a rejected new password never consumes a
 * current-password attempt — `docs/09-api-contracts.md` Section 10.
 */
final class ChangePasswordRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'current_password' => ['required', 'string', 'max:128'],
            'new_password' => ['required', 'string', 'min:10', 'max:128', 'confirmed'],
            'new_password_confirmation' => ['required', 'string'],
        ];
    }
}
