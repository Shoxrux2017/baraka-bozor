<?php

declare(strict_types=1);

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;

/**
 * The query of a paginated list (`docs/09-api-contracts.md` section 5):
 * `page` from 1 to 100 000, `per_page` from 1 to 100, default 20.
 *
 * A plain form request, not a strict one: the strict request shape of `09`
 * section 4 governs mutation bodies, and a list tolerates a query parameter
 * it does not know. A parameter sent empty (`category_id=`) means the same as
 * one not sent, because a client that serialises an unset filter as an empty
 * string should not be refused for it (`DL-20` (2)). A list adds its own
 * filters in [filters].
 */
abstract class ListRequest extends FormRequest
{
    public const DEFAULT_PER_PAGE = 20;

    public const MAX_PER_PAGE = 100;

    /** Far beyond any real list, and well inside integer arithmetic. */
    public const MAX_PAGE = 100_000;

    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    final public function rules(): array
    {
        return [
            'page' => ['sometimes', 'nullable', 'integer', 'min:1', 'max:'.self::MAX_PAGE],
            'per_page' => ['sometimes', 'nullable', 'integer', 'min:1', 'max:'.self::MAX_PER_PAGE],
            ...$this->filters(),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    abstract protected function filters(): array;

    public function page(): int
    {
        return (int) ($this->validated('page') ?? 1);
    }

    public function perPage(): int
    {
        return (int) ($this->validated('per_page') ?? self::DEFAULT_PER_PAGE);
    }

    /**
     * A query-string flag, `true`/`false`/`1`/`0`, absent or empty meaning
     * false.
     */
    protected function flag(string $key): bool
    {
        return in_array($this->validated($key), ['true', '1'], true);
    }

    /**
     * A query-string value, absent or empty meaning null.
     */
    protected function text(string $key): ?string
    {
        $value = $this->validated($key);

        return is_string($value) && $value !== '' ? $value : null;
    }
}
