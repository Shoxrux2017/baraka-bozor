<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * The online payment providers `DL-2` 3.3 names: Payme and Click first, Paynet
 * and xazna later. All four exist as rows from the start so enabling one is a
 * setting, not a migration (`BR-SET-004`).
 */
enum PaymentProvider: string
{
    case Payme = 'payme';
    case Click = 'click';
    case Paynet = 'paynet';
    case Xazna = 'xazna';
}
