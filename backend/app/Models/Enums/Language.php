<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * The two languages of the product's texts: Uzbek and Russian.
 */
enum Language: string
{
    case Uz = 'uz';
    case Ru = 'ru';
}
