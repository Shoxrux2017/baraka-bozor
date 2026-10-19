<?php

declare(strict_types=1);

namespace App\Modules\Legal;

/**
 * Parses the plain text an Admin writes into blocks (`DL-94` item 1): a line
 * starting with `## ` is a heading, one starting with `- ` a list item, any
 * other non-blank line a paragraph. Nothing is ever interpreted as HTML; the
 * text of a block is the literal text of the line.
 */
final class LegalText
{
    /**
     * @return list<array{type: string, text: string}>
     */
    public static function blocks(string $body): array
    {
        $blocks = [];

        foreach (preg_split('/\r\n|\r|\n/', $body) ?: [] as $rawLine) {
            $line = trim($rawLine);

            if ($line === '' || $line === '##' || $line === '-') {
                continue;
            }

            if (str_starts_with($line, '## ')) {
                $type = 'heading';
                $text = trim(substr($line, 3));
            } elseif (str_starts_with($line, '- ')) {
                $type = 'item';
                $text = trim(substr($line, 2));
            } else {
                $type = 'paragraph';
                $text = $line;
            }

            if ($text !== '') {
                $blocks[] = ['type' => $type, 'text' => $text];
            }
        }

        return $blocks;
    }
}
