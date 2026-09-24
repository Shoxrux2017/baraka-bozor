<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Requests;

use App\Http\Requests\StrictFormRequest;
use App\Modules\Auth\LoginCodePolicy;

final class StaffLoginRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'phone' => ['required', 'string', 'regex:'.LoginCodePolicy::PHONE_PATTERN],
            'password' => ['required', 'string', 'max:128'],
        ];
    }
}
