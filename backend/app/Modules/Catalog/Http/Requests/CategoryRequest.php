<?php

declare(strict_types=1);

namespace App\Modules\Catalog\Http\Requests;

use App\Http\Requests\StrictFormRequest;

/**
 * The category write body of `docs/09` section 15: every field required on
 * create, any subset on update. Names fit their `varchar(120)` columns
 * (`DL-18` (1)).
 */
final class CategoryRequest extends StrictFormRequest
{
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
