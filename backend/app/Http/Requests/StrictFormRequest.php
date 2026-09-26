<?php

declare(strict_types=1);

namespace App\Http\Requests;

use Illuminate\Contracts\Validation\Validator;
use Illuminate\Foundation\Http\FormRequest;

/**
 * A form request that rejects fields it does not declare, at every depth.
 *
 * `docs/09-api-contracts.md` Section 4: mutation endpoints reject unknown
 * fields with `validation_failed`. Laravel ignores undeclared input by default,
 * which is how a client ends up sending `role`, or `items[0][price]`, for years
 * without anyone noticing that it is dropped — or, after a careless refactor,
 * that it is not. Refusing it keeps the request shape a contract.
 *
 * The declared shape is the tree of rule keys: `items.*.product_id` declares
 * `items`, any index below it, and `product_id` below that. A declared key with
 * no rules below it is a leaf and accepts whatever it holds. Only the body —
 * its fields and its uploaded files — is checked; query-string parameters are
 * not part of a mutation's shape.
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
            // Uploaded files are part of the body too: a multipart request
            // with an undeclared file field is refused like an undeclared
            // text field.
            /** @var array<array-key, mixed> $body */
            $body = array_merge($this->getInputSource()->all(), $this->allFiles());

            $this->rejectUndeclared($validator, $body, $this->declaredTree(), '');
        });
    }

    /**
     * @return array<string, mixed>
     */
    abstract public function rules(): array;

    /**
     * The declared keys as a tree: `a.*.b` becomes ['a' => ['*' => ['b' => []]]].
     *
     * @return array<string, mixed>
     */
    private function declaredTree(): array
    {
        $tree = [];

        foreach (array_keys($this->rules()) as $key) {
            $tree = $this->insert($tree, explode('.', (string) $key));
        }

        return $tree;
    }

    /**
     * @param  array<string, mixed>  $tree
     * @param  list<string>  $segments
     * @return array<string, mixed>
     */
    private function insert(array $tree, array $segments): array
    {
        if ($segments === []) {
            return $tree;
        }

        $head = array_shift($segments);
        $existing = $tree[$head] ?? [];

        $tree[$head] = $this->insert(is_array($existing) ? $existing : [], $segments);

        return $tree;
    }

    /**
     * @param  array<array-key, mixed>  $input
     * @param  array<string, mixed>  $declared
     */
    private function rejectUndeclared(Validator $validator, array $input, array $declared, string $path): void
    {
        foreach ($input as $key => $value) {
            $child = $declared[(string) $key] ?? $declared['*'] ?? null;

            if ($child === null) {
                $validator->errors()->add($path.$key, 'This field is not accepted.');

                continue;
            }

            // A declared key with nothing below it is a leaf: its contents are
            // the rule's business, not the shape's.
            if (is_array($value) && is_array($child) && $child !== []) {
                $this->rejectUndeclared($validator, $value, $child, $path.$key.'.');
            }
        }
    }
}
