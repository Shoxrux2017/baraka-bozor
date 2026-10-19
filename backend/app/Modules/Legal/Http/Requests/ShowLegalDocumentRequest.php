<?php

declare(strict_types=1);

namespace App\Modules\Legal\Http\Requests;

use App\Modules\Legal\LegalDocuments;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * The `language` query of the public document routes (`docs/09` Sections
 * 61 and 62): `uz` or `ru`, absent meaning `uz`.
 */
final class ShowLegalDocumentRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, mixed>
     */
    public function rules(): array
    {
        return [
            'language' => ['nullable', 'string', Rule::in(LegalDocuments::LANGUAGES)],
        ];
    }

    public function language(): string
    {
        $language = $this->validated('language');

        return is_string($language) ? $language : 'uz';
    }
}
