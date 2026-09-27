<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * Who wrote an `order_history` row; only a `user` row names an actor.
 */
enum HistoryActorType: string
{
    case User = 'user';
    case System = 'system';
    case PaymentProvider = 'payment_provider';
}
