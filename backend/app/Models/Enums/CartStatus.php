<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * A cart is `active` until an order converts it (`BR-CHK-008`); `abandoned` was
 * dropped (`DL-3` S-14).
 */
enum CartStatus: string
{
    case Active = 'active';
    case Converted = 'converted';
}
