<?php

declare(strict_types=1);

namespace App\Modules\Legal\Http\Controllers;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Models\Enums\LegalDocumentKind;
use App\Modules\Legal\Http\Requests\ShowLegalDocumentRequest;
use App\Modules\Legal\LegalDocuments;
use App\Modules\Legal\LegalText;
use Illuminate\Http\JsonResponse;

/**
 * `GET /legal` and `GET /legal/{kind}` (`docs/09` Sections 61 and 62). Public:
 * the app shows the documents before sign-in and Google Play links to them.
 */
final class LegalDocumentController extends Controller
{
    public function index(ShowLegalDocumentRequest $request, LegalDocuments $documents): JsonResponse
    {
        $data = [];

        foreach (LegalDocumentKind::cases() as $kind) {
            $document = $documents->published($kind, $request->language());

            $data[$kind->value] = $document === null ? null : [
                'language' => $document->language,
                'updated_at' => $document->created_at->toIso8601ZuluString(),
            ];
        }

        return response()->json(['data' => $data]);
    }

    public function show(ShowLegalDocumentRequest $request, string $kind, LegalDocuments $documents): JsonResponse
    {
        $known = LegalDocumentKind::from($kind);
        $document = $documents->published($known, $request->language());

        if ($document === null || $document->body === null) {
            throw ApiException::notFound();
        }

        return response()->json(['data' => [
            'kind' => $known->value,
            'language' => $document->language,
            'updated_at' => $document->created_at->toIso8601ZuluString(),
            'blocks' => LegalText::blocks($document->body),
        ]]);
    }
}
