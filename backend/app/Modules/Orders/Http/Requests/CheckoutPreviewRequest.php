<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\StrictFormRequest;
use App\Models\Enums\PaymentMethod;
use Illuminate\Validation\Rule;

/**
 * A checkout to preview (`docs/09` section 18): an own address, `cash` or
 * `online`, and an optional free-text delivery wish of up to 160 characters
 * (interview 1.3, `docs/08` section 13).
 */
final class CheckoutPreviewRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'address_id' => ['required', 'string', 'uuid'],
            'payment_method' => ['required', 'string', Rule::enum(PaymentMethod::class)],
            'delivery_time_note' => ['sometimes', 'nullable', 'string', 'max:160'],
        ];
    }
}
