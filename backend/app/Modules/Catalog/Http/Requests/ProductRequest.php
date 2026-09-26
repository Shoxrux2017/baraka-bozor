<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Http\Requests;

use App\Http\Requests\StrictFormRequest;
use App\Models\Enums\PriceMode;
use App\Models\Enums\UnitCode;
use Illuminate\Validation\Rule;

/**
 * The product write body of `docs/09` section 15: every field required on
 * create, any subset on update. A product lives in an existing, unarchived
 * category; its market price is a positive whole number of UZS; names fit
 * their `varchar(160)` columns (`DL-18` (1)).
 */
final class ProductRequest extends StrictFormRequest
{
    /** No product at a wholesale market costs a billion UZS. */
    public const MAX_MARKET_PRICE_UZS = 1_000_000_000;

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $presence = $this->isMethod('POST') ? 'required' : 'sometimes';

        return [
            // `bail`: a malformed id must stop before the `exists` query, which
            // PostgreSQL would answer with an invalid-uuid error.
            'category_id' => [
                'bail', $presence, 'required', 'string', 'uuid',
                Rule::exists('categories', 'id')->whereNull('archived_at'),
            ],
            'name_uz' => [$presence, 'required', 'string', 'max:160'],
            'name_ru' => [$presence, 'required', 'string', 'max:160'],
            'description_uz' => ['sometimes', 'nullable', 'string', 'max:2000'],
            'description_ru' => ['sometimes', 'nullable', 'string', 'max:2000'],
            'unit_code' => [$presence, 'required', 'string', Rule::enum(UnitCode::class)],
            'price_mode' => [$presence, 'required', 'string', Rule::enum(PriceMode::class)],
            'market_price_uzs' => [$presence, 'required', 'integer:strict', 'min:1', 'max:'.self::MAX_MARKET_PRICE_UZS],
            'sort_order' => ['sometimes', 'required', 'integer:strict', 'between:-100000,100000'],
            'is_active' => ['sometimes', 'required', 'boolean:strict'],
        ];
    }
}
