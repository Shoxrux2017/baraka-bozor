<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\StrictFormRequest;
use App\Models\Enums\SubstitutionPolicy;
use Illuminate\Validation\Rule;

/**
 * A line added to the cart (`docs/09` section 17). The quantity is a string,
 * as every quantity the client sends (`docs/07` section 14); whether it fits
 * the product's unit is checked once the product is known (`QuantityPolicy`).
 * The rule defaults to `allow_similar_substitution` (`BR-CART-004`).
 */
final class AddCartItemRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'product_id' => ['required', 'string', 'uuid'],
            'quantity' => ['required', 'string'],
            'customer_note' => ['sometimes', 'nullable', 'string', 'max:300'],
            'substitution_policy' => ['sometimes', 'required', 'string', Rule::enum(SubstitutionPolicy::class)],
        ];
    }
}
