<?php

declare(strict_types=1);

namespace App\Modules\Legal\Actions;

use App\Models\Enums\LegalDocumentKind;
use App\Models\LegalDocument;
use App\Models\User;
use App\Modules\Legal\LegalDocuments;
use Illuminate\Support\Facades\DB;

/**
 * Appends an edition of a document (`DL-94` item 1). A body that equals the one
 * in force adds nothing; a blank body unpublishes.
 */
final class PublishLegalDocument
{
    public function __construct(private readonly LegalDocuments $documents) {}

    public function publish(User $admin, LegalDocumentKind $kind, string $language, ?string $body): LegalDocument
    {
        $normalised = $body === null ? '' : trim(str_replace(["\r\n", "\r"], "\n", $body));
        $normalised = $normalised === '' ? null : $normalised;

        return DB::transaction(function () use ($admin, $kind, $language, $normalised): LegalDocument {
            // Serialise concurrent saves of one document so the comparison
            // below sees the edition the other save wrote.
            DB::select('select pg_advisory_xact_lock(hashtext(?))', ["legal:{$kind->value}:{$language}"]);

            $current = $this->documents->current($kind, $language);

            if ($current !== null && $current->body === $normalised) {
                return $current;
            }

            $document = new LegalDocument;
            $document->kind = $kind->value;
            $document->language = $language;
            $document->body = $normalised;
            $document->created_by_user_id = $admin->id;
            $document->save();

            return $document;
        });
    }
}
