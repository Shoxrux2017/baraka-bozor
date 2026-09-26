<?php

declare(strict_types=1);

namespace App\Modules\Settings\Http\Requests;

use App\Http\Requests\StrictFormRequest;

final class UpdatePaymentProviderSettingRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'is_enabled' => ['required', 'boolean:strict'],
        ];
    }
}
