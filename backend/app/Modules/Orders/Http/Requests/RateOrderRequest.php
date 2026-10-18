<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\StrictFormRequest;
use App\Models\Enums\RatingReason;
use App\Modules\Orders\OrderRatings;
use Closure;
use Illuminate\Validation\Rule;

/**
 * A Customer's rating (`docs/09` section 59): `stars` as an integer from 1 to
 * 5, `reasons` only at 1 to 3 stars and each at most once, and a `comment` of
 * up to 500 characters.
 */
final class RateOrderRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'stars' => ['required', static function (string $attribute, mixed $value, Closure $fail): void {
                if (! is_int($value) || $value < 1 || $value > 5) {
                    $fail('The stars must be an integer from 1 to 5.');
                }
            }],
            'reasons' => ['sometimes', 'nullable', 'array', function (string $attribute, mixed $value, Closure $fail): void {
                $stars = $this->input('stars');

                if (is_array($value) && $value !== [] && is_int($stars) && $stars > OrderRatings::LOW_MAX_STARS) {
                    $fail('Reasons are given only for 1 to 3 stars.');
                }
            }],
            'reasons.*' => ['string', 'distinct', Rule::enum(RatingReason::class)],
            'comment' => ['sometimes', 'nullable', 'string', 'max:500'],
        ];
    }

    public function stars(): int
    {
        return (int) $this->validated('stars');
    }

    /**
     * @return list<string>
     */
    public function reasons(): array
    {
        $reasons = $this->validated('reasons');

        return is_array($reasons) ? array_values(array_map(strval(...), $reasons)) : [];
    }

    public function comment(): ?string
    {
        $comment = $this->validated('comment');

        return is_string($comment) && trim($comment) !== '' ? trim($comment) : null;
    }
}
