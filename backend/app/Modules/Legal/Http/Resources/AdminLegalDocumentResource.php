<?php

declare(strict_types=1);

namespace App\Modules\Legal\Http\Resources;

use App\Models\Enums\LegalDocumentKind;
use App\Models\LegalDocument;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * One document in one language as the Admin editor sees it (`docs/09`
 * Section 63). The editor lists a slot even when nothing was ever saved, so
 * the resource takes the kind and language beside the (optional) edition.
 */
final class AdminLegalDocumentResource extends JsonResource
{
    public function __construct(
        private readonly LegalDocumentKind $kind,
        private readonly string $language,
        private readonly ?LegalDocument $document,
    ) {
        parent::__construct($document);
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $author = $this->document?->author;

        return [
            'kind' => $this->kind->value,
            'language' => $this->language,
            'body' => $this->document?->body,
            'updated_at' => $this->document?->created_at->toIso8601ZuluString(),
            'updated_by' => $author === null ? null : ['id' => $author->id, 'full_name' => $author->full_name],
        ];
    }
}
