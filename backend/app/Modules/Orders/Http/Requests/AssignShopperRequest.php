<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\StrictFormRequest;

/**
 * The Shopper to assign or reassign (`docs/09` section 39): `shopper_id`, a
 * UUID. Whether it is a Shopper's account is decided under the order lock.
 */
final class AssignShopperRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'shopper_id' => ['required', 'string', 'uuid'],
        ];
    }

    public function shopperId(): string
    {
        return strtolower((string) $this->validated('shopper_id'));
    }
}
