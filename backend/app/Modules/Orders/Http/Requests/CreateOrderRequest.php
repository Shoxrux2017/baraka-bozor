<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\StrictFormRequest;

/**
 * An order from a preview (`docs/09` section 19): the checkout token alone.
 * The address, the payment method and the delivery wish travel inside it, so
 * the order is exactly the checkout the Customer was shown.
 */
final class CreateOrderRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'checkout_token' => ['required', 'string', 'max:4096'],
        ];
    }
}
