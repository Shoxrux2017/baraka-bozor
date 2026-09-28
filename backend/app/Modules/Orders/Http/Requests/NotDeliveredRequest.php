<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\StrictFormRequest;
use App\Models\Enums\DeliveryFailureReason;
use Illuminate\Validation\Rule;

/**
 * Why a delivery failed (`docs/09` section 37, `BR-DEL-003`): `reason_code`,
 * one of `no_answer`, `refused`, `wrong_address` or `other`, and a note of up to
 * 300 characters, required with `other`.
 */
final class NotDeliveredRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'reason_code' => ['required', 'string', Rule::enum(DeliveryFailureReason::class)],
            'note' => ['required_if:reason_code,'.DeliveryFailureReason::Other->value, 'nullable', 'string', 'max:300'],
        ];
    }

    public function reason(): DeliveryFailureReason
    {
        return DeliveryFailureReason::from((string) $this->validated('reason_code'));
    }

    public function note(): ?string
    {
        $note = $this->validated('note');

        return is_string($note) ? $note : null;
    }
}
