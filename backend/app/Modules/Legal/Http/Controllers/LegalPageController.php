<?php

declare(strict_types=1);

namespace App\Modules\Legal\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Models\BusinessSettings;
use App\Models\Enums\LegalDocumentKind;
use App\Modules\Legal\LegalDocuments;
use App\Modules\Legal\LegalPageTexts;
use App\Modules\Legal\LegalText;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

/**
 * The public pages of the documents and of the account-deletion instructions
 * (`docs/09` Section 61, `DL-94` item 2). Server-rendered HTML for the store
 * listing; every value goes through Blade's escaping.
 */
final class LegalPageController extends Controller
{
    private const ZONE = 'Asia/Tashkent';

    public function document(Request $request, string $kind, LegalDocuments $documents): Response
    {
        $known = LegalDocumentKind::tryFrom($kind);

        if ($known === null) {
            abort(404);
        }

        $asked = LegalPageTexts::language($request->query('lang'));
        $document = $documents->published($known, $asked);
        $language = $document === null ? $asked : $document->language;

        $view = view('legal.document', [
            'language' => $language,
            'switchUrl' => $this->url('/legal/'.$known->value, LegalPageTexts::otherLanguage($language)),
            'switchName' => LegalPageTexts::languageName(LegalPageTexts::otherLanguage($language)),
            'title' => LegalPageTexts::documentTitle($known, $language),
            'edition' => $document === null ? null : LegalPageTexts::edition($language).' '
                .$document->created_at->copy()->setTimezone(self::ZONE)->format('d.m.Y'),
            'blocks' => $document === null ? [] : $this->grouped(LegalText::blocks((string) $document->body)),
            'notPublished' => LegalPageTexts::notPublished($language),
        ]);

        return response($view, $document === null ? 404 : 200)
            ->header('Content-Type', 'text/html; charset=utf-8');
    }

    public function accountDeletion(Request $request): Response
    {
        $language = LegalPageTexts::language($request->query('lang'));
        $phone = BusinessSettings::current()->support_phone;
        $texts = LegalPageTexts::deletion($language, $phone);

        $view = view('legal.account-deletion', [
            'language' => $language,
            'switchUrl' => $this->url('/account-deletion', LegalPageTexts::otherLanguage($language)),
            'switchName' => LegalPageTexts::languageName(LegalPageTexts::otherLanguage($language)),
            'title' => $texts['title'],
            'texts' => $texts,
            'privacyUrl' => $this->url('/legal/privacy', $language),
        ]);

        return response($view)->header('Content-Type', 'text/html; charset=utf-8');
    }

    private function url(string $path, string $language): string
    {
        return $path.'?lang='.$language;
    }

    /**
     * Consecutive list items become one list, so the view can open one `ul`.
     *
     * @param  list<array{type: string, text: string}>  $blocks
     * @return list<array{type: string, text: string, items: list<string>}>
     */
    private function grouped(array $blocks): array
    {
        $grouped = [];

        foreach ($blocks as $block) {
            $last = array_key_last($grouped);

            if ($block['type'] === 'item') {
                if ($last !== null && $grouped[$last]['type'] === 'list') {
                    $grouped[$last]['items'][] = $block['text'];
                } else {
                    $grouped[] = ['type' => 'list', 'text' => '', 'items' => [$block['text']]];
                }

                continue;
            }

            $grouped[] = ['type' => $block['type'], 'text' => $block['text'], 'items' => []];
        }

        return $grouped;
    }
}
