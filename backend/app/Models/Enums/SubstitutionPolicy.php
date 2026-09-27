<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * The Customer's rule for an item the Shopper cannot buy as ordered (`01`
 * Section 10); the first is the default (`BR-CART-004`).
 */
enum SubstitutionPolicy: string
{
    case AllowSimilar = 'allow_similar_substitution';
    case ContactBefore = 'contact_before_substitution';
    case RemoveIfUnavailable = 'remove_if_unavailable';
}
