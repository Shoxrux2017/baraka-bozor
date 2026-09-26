<?php

declare(strict_types=1);

namespace App\Http\Requests\Concerns;

use Illuminate\Validation\Validator;

/**
 * A PATCH that names no field changes nothing, yet saving it would still
 * touch `updated_at` and whatever records the last editor; it is refused with
 * `422` on `body` (`DL-19` (6)). The same refusal catches a body the JSON
 * decoder could not read, which the framework hands over as empty.
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
                if ($this->isMethod('PATCH') && $this->all() === []) {
                    $validator->errors()->add('body', 'Name at least one field to change.');
                }
            },
        ];
    }
}
