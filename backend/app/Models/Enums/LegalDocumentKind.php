<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * The two legal documents (`08` Section 34), in the order the panel lists them.
 */
enum LegalDocumentKind: string
{
    case Terms = 'terms';
    case Privacy = 'privacy';
}
