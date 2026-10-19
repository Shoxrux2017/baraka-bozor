<?php

declare(strict_types=1);

namespace App\Modules\Legal;

use App\Models\Enums\LegalDocumentKind;
use App\Models\LegalDocument;

/**
 * Reads the documents in force (`08` Section 34).
 */
final class LegalDocuments
{
    /** @var list<string> */
    public const LANGUAGES = ['uz', 'ru'];

    /**
     * The newest row of the kind and language; its body may be null.
     */
    public function current(LegalDocumentKind $kind, string $language): ?LegalDocument
    {
        return LegalDocument::query()
            ->where('kind', $kind->value)
            ->where('language', $language)
            ->orderByDesc('edition')
            ->first();
    }

    /**
     * The published text in the asked language, or else in the other one.
     */
    public function published(LegalDocumentKind $kind, string $language): ?LegalDocument
    {
        $others = array_values(array_diff(self::LANGUAGES, [$language]));

        foreach ([$language, ...$others] as $candidate) {
            $document = $this->current($kind, $candidate);

            if ($document !== null && $document->body !== null) {
                return $document;
            }
        }

        return null;
    }
}
