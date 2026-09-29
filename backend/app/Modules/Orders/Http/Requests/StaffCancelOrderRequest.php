<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\StrictFormRequest;
use App\Models\Enums\CancellationReason;
use Illuminate\Validation\Rule;

/**
 * The Operator's cancellation (`docs/09` section 41): `reason_code`, which in
 * Wave 3 is `delivery_failed` alone — `unpaid_online` arrives with Wave 5
 * (`DL-65` (3)) — and an optional note of up to 300 characters.
 */
final class StaffCancelOrderRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'reason_code' => ['required', 'string', Rule::in([CancellationReason::DeliveryFailed->value])],
            'note' => ['sometimes', 'nullable', 'string', 'max:300'],
        ];
    }

    public function note(): ?string
    {
        $note = $this->validated('note');

        return is_string($note) ? $note : null;
    }
}
