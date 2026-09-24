<?php

declare(strict_types=1);

namespace App\Http\Requests;

use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;

/**
 * A form request that rejects fields it does not declare.
 *
 * `docs/09-api-contracts.md` Section 4: mutation endpoints reject unknown
 * fields with `validation_failed`. Laravel ignores undeclared input by default,
 * which is how a client ends up sending `role` or `status` for years without
 * anyone noticing that it is dropped — or, after a careless refactor, that it
 * is not. Refusing it keeps the request shape a contract.
 */
abstract class StrictFormRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    public function withValidator(Validator $validator): void
    {
        $validator->after(function (Validator $validator): void {
            $declared = array_map(
                static fn (string $rule): string => explode('.', $rule)[0],
                array_keys($this->rules())
            );

            foreach (array_keys($this->all()) as $field) {
                if (! in_array((string) $field, $declared, true)) {
                    $validator->errors()->add((string) $field, 'This field is not accepted.');
                }
            }
        });
    }

    /**
     * @return array<string, mixed>
     */
    abstract public function rules(): array;
}
