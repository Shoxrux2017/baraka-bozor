<?php

declare(strict_types=1);

namespace App\Http\Requests\Concerns;

use Illuminate\Validation\Validator;

/**
 * A PATCH that names no field changes nothing, yet saving it would still
 * touch `updated_at` and whatever records the last editor; it is refused with
 * `422` on `body` (`DL-19` (6)). Only the body and its files count: a query
 * string names no field of a PATCH. A body the JSON decoder cannot read never
 * gets here; it is `400 malformed_request` (`DL-24`).
 */
trait RefusesEmptyPatch
{
    /**
     * @return list<callable(Validator): void>
     */
    public function after(): array
    {
        return [
            function (Validator $validator): void {
                if ($this->isMethod('PATCH') && $this->getInputSource()->all() === [] && $this->allFiles() === []) {
                    $validator->errors()->add('body', 'Name at least one field to change.');
                }
            },
        ];
    }
}
