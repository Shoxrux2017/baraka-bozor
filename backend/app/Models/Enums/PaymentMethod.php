<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * Chosen at checkout (`BR-PAY-002`): cash to the Courier, or online after
 * shopping.
 */
enum PaymentMethod: string
{
    case Cash = 'cash';
    case Online = 'online';
}
