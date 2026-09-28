<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * How an approval was resolved: the Customer's approval or rejection, or an
 * Operator removing the line of an expired one (`BR-APP-007`).
 */
enum ApprovalResolution: string
{
    case Approved = 'approved';
    case Rejected = 'rejected';
    case RemoveItem = 'remove_item';
}
