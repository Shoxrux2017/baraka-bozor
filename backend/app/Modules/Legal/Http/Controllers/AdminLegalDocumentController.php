<?php

declare(strict_types=1);

namespace App\Modules\Legal\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Models\Enums\LegalDocumentKind;
use App\Models\User;
use App\Modules\Legal\Actions\PublishLegalDocument;
use App\Modules\Legal\Http\Requests\PublishLegalDocumentRequest;
use App\Modules\Legal\Http\Resources\AdminLegalDocumentResource;
use App\Modules\Legal\LegalDocuments;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * `GET /admin/legal-documents` and `PUT /admin/legal-documents/{kind}/{language}`
 * (`docs/09` Section 63). Admin only; the route declares it and constrains the
 * kind and the language, so an unknown one is the plain `404`.
 */
final class AdminLegalDocumentController extends Controller
{
    public function index(Request $request, LegalDocuments $documents): JsonResponse
    {
        $entries = [];

        foreach (LegalDocumentKind::cases() as $kind) {
            foreach (LegalDocuments::LANGUAGES as $language) {
                $entries[] = (new AdminLegalDocumentResource($kind, $language, $documents->current($kind, $language)))
                    ->resolve($request);
            }
        }

        return response()->json(['data' => $entries]);
    }

    public function update(
        PublishLegalDocumentRequest $request,
        string $kind,
        string $language,
        PublishLegalDocument $publish,
    ): JsonResponse {
        $admin = $request->user();

        if (! $admin instanceof User) {
            abort(401);
        }

        $known = LegalDocumentKind::from($kind);
        $body = $request->validated('body');

        // A resource over a just-created model would answer 201; a save is a
        // PUT of the whole document and always answers 200.
        return (new AdminLegalDocumentResource(
            $known,
            $language,
            $publish->publish($admin, $known, $language, is_string($body) ? $body : null)
        ))->response($request)->setStatusCode(200);
    }
}
