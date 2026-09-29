<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\StrictFormRequest;

/**
 * The handover (`docs/09` section 37): `cash_received_uzs`, the cash taken, a
 * whole number of UZS. Whether the order needs it, and whether it equals the
 * final total, is decided under the order lock (`BR-DEL-004`).
 */
final class DeliveredRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'cash_received_uzs' => ['sometimes', 'nullable', 'integer:strict', 'min:1'],
        ];
    }

    public function cashReceivedUzs(): ?int
    {
        $value = $this->validated('cash_received_uzs');

        return is_int($value) ? $value : null;
    }
}
