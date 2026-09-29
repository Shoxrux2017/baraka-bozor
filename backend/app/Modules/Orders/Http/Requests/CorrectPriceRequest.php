<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\StrictFormRequest;
use App\Modules\Catalog\Http\Requests\ProductRequest;

/**
 * An Admin's price correction (`docs/09` section 45): the market price the
 * Shopper really paid, a whole number of UZS within the catalog's bounds, and
 * the reason, of up to 300 characters, which the correction and the history
 * keep.
 */
final class CorrectPriceRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'actual_market_price_uzs' => ['required', 'integer:strict', 'min:1', 'max:'.ProductRequest::MAX_MARKET_PRICE_UZS],
            'reason' => ['required', 'string', 'max:300'],
        ];
    }

    public function actualMarketPriceUzs(): int
    {
        return (int) $this->validated('actual_market_price_uzs');
    }

    public function reason(): string
    {
        return (string) $this->validated('reason');
    }
}
