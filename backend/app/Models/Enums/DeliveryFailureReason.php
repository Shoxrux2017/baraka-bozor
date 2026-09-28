<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * Why a Courier could not deliver (`BR-DEL-003`, interview 5.3); `other`
 * comes with a note.
 */
enum DeliveryFailureReason: string
{
    case NoAnswer = 'no_answer';
    case Refused = 'refused';
    case WrongAddress = 'wrong_address';
    case Other = 'other';
}
