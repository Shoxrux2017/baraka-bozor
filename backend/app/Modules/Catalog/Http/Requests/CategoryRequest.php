<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Http\Requests;

use App\Http\Requests\Concerns\RefusesEmptyPatch;
use App\Http\Requests\StrictFormRequest;

/**
 * The category write body of `docs/09` section 15. Both names are required
 * on create; the descriptions, `sort_order` (default 0) and `is_active`
 * (default true) are optional; an update takes any non-empty subset. Names fit
 * their `varchar(120)` columns (`DL-18` (1)); the other bounds are `DL-20`'s.
 */
final class CategoryRequest extends StrictFormRequest
{
    use RefusesEmptyPatch;

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        $presence = $this->isMethod('POST') ? 'required' : 'sometimes';

        return [
            'name_uz' => [$presence, 'required', 'string', 'max:120'],
            'name_ru' => [$presence, 'required', 'string', 'max:120'],
            'description_uz' => ['sometimes', 'nullable', 'string', 'max:2000'],
            'description_ru' => ['sometimes', 'nullable', 'string', 'max:2000'],
            'sort_order' => ['sometimes', 'required', 'integer:strict', 'between:-100000,100000'],
            'is_active' => ['sometimes', 'required', 'boolean:strict'],
        ];
    }
}
