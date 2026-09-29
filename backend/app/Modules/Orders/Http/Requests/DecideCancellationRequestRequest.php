<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Requests;

use App\Http\Requests\StrictFormRequest;
use App\Modules\Orders\Actions\DecideCancellationRequest;
use Illuminate\Validation\Rule;

/**
 * An Operator's decision on a cancellation request (`docs/09` section 40):
 * `decision`, `approve` or `reject`, and an optional note of up to 300
 * characters, kept on the request and the history row.
 */
final class DecideCancellationRequestRequest extends StrictFormRequest
{
    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'decision' => ['required', 'string', Rule::in([DecideCancellationRequest::APPROVE, DecideCancellationRequest::REJECT])],
            'note' => ['sometimes', 'nullable', 'string', 'max:300'],
        ];
    }

    public function decision(): string
    {
        return (string) $this->validated('decision');
    }

    public function note(): ?string
    {
        $note = $this->validated('note');

        return is_string($note) ? $note : null;
    }
}
