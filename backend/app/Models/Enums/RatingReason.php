<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * Why a Customer rated a delivered order 1 to 3 stars (`DL-90` (1)): each at
 * most once, never with 4 or 5 stars (`BR-RATE-002`).
 */
enum RatingReason: string
{
    case NotFresh = 'not_fresh';
    case WrongWeight = 'wrong_weight';
    case Late = 'late';
    case Rude = 'rude';
}
