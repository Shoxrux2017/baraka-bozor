<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\StrictFormRequest;

/**
 * The Courier of a first assignment (`docs/09` section 39): `courier_id`, a
 * UUID. Whether it is a Courier's account is decided under the order lock.
 */
final class AssignCourierRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'courier_id' => ['required', 'string', 'uuid'],
        ];
    }

    public function courierId(): string
    {
        return strtolower((string) $this->validated('courier_id'));
    }
}
