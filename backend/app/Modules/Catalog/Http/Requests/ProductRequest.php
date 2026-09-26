<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Http\Requests;

use App\Http\Requests\Concerns\RefusesEmptyPatch;
use App\Http\Requests\StrictFormRequest;
use App\Models\Enums\PriceMode;
use App\Models\Enums\UnitCode;
use Illuminate\Validation\Rule;

/**
 * The product write body of `docs/09` section 15. The category, both names,
 * the unit, the price mode and the market price are required on create; the
 * descriptions, `sort_order` (default 0) and `is_active` (default true) are
 * optional; an update takes any non-empty subset. Names fit their
 * `varchar(160)` columns (`DL-18` (1)); the other bounds are `DL-20`'s.
 *
 * Only the shape of `category_id` is checked here. Whether that category
 * exists and is open depends on the database at the moment of the write, so
 * the action decides it under a lock (`SaveCatalogEntry`).
 */
final class ProductRequest extends StrictFormRequest
{
    use RefusesEmptyPatch;

    /** No product at a wholesale market costs a billion UZS. */
    public const MAX_MARKET_PRICE_UZS = 1_000_000_000;

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $presence = $this->isMethod('POST') ? 'required' : 'sometimes';

        return [
            'category_id' => [$presence, 'required', 'string', 'uuid'],
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
