<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\StrictFormRequest;
use App\Modules\Catalog\Http\Requests\ProductRequest;

/**
 * A proposed replacement (`docs/09` section 33): the product, the market price
 * the stall charges for one unit of it, and an optional note for the
 * Customer.
 */
final class ProposeSubstitutionRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'replacement_product_id' => ['required', 'string', 'uuid'],
            'actual_market_price_uzs' => ['required', 'integer:strict', 'min:1', 'max:'.ProductRequest::MAX_MARKET_PRICE_UZS],
            'note' => ['sometimes', 'nullable', 'string', 'max:300'],
        ];
    }
}
