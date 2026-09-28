<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\StrictFormRequest;
use App\Modules\Catalog\Http\Requests\ProductRequest;

/**
 * A price question (`docs/09` section 32): the market price the stall charges
 * for one unit, a JSON integer within the catalog's bound; the product it is
 * about, when named; an optional note for the Customer.
 */
final class AskAboutPriceRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'actual_market_price_uzs' => ['required', 'integer:strict', 'min:1', 'max:'.ProductRequest::MAX_MARKET_PRICE_UZS],
            'fulfilled_product_id' => ['sometimes', 'nullable', 'string', 'uuid'],
            'note' => ['sometimes', 'nullable', 'string', 'max:300'],
        ];
    }
}
