<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\StrictFormRequest;

/**
 * A Customer's cancellation (`docs/09` section 22): an optional reason of up
 * to 300 characters for a direct cancellation (`DL-37` (13)).
 */
final class CancelOrderRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'reason' => ['sometimes', 'nullable', 'string', 'max:300'],
        ];
    }
}
