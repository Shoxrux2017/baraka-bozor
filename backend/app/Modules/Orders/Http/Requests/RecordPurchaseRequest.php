<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\StrictFormRequest;
use App\Modules\Catalog\Http\Requests\ProductRequest;

/**
 * A Shopper's purchase (`docs/09` section 30): the quantity bought, a decimal
 * string held to the line's unit by the action (`QuantityPolicy`); the market
 * price paid for one unit, a JSON integer within the catalog's own bound; and
 * the product bought, when it is named.
 */
final class RecordPurchaseRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'purchased_quantity' => ['required', 'string'],
            'actual_market_price_uzs' => ['sometimes', 'nullable', 'integer:strict', 'min:1', 'max:'.ProductRequest::MAX_MARKET_PRICE_UZS],
            'fulfilled_product_id' => ['sometimes', 'nullable', 'string', 'uuid'],
        ];
    }
}
