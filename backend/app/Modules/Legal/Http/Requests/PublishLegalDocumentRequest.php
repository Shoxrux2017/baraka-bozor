<?php

declare(strict_types=1);

namespace App\Modules\Legal\Http\Requests;

use App\Http\Requests\StrictFormRequest;

/**
 * `PUT /admin/legal-documents/{kind}/{language}` body (`docs/09` Section 63):
 * `body` is always present; null or blank unpublishes.
 */
final class PublishLegalDocumentRequest extends StrictFormRequest
{
    public const MAX_LENGTH = 50000;

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'body' => ['present', 'nullable', 'string', 'max:'.self::MAX_LENGTH],
        ];
    }
}
