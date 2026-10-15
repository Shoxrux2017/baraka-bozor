<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Requests;

use App\Http\Requests\StrictFormRequest;

final class StaffStepRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'staff_step' => ['required', 'string', 'size:64'],
            'password' => ['required', 'string', 'max:128'],
        ];
    }
}
