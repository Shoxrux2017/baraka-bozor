<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Requests;

use App\Http\Requests\StrictFormRequest;
use App\Modules\Auth\LoginCodePolicy;

final class VerifyCustomerLoginCodeRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'phone' => ['required', 'string', 'regex:/^\+998[0-9]{9}$/'],
            'code' => ['required', 'string', 'regex:/^[0-9]{'.LoginCodePolicy::DIGITS.'}$/'],
        ];
    }
}
