<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * How a replacement was authorized (`DL-3` S-9).
 */
enum SubstitutionResolution: string
{
    case Automatic = 'automatic';
    case Approved = 'approved';
}
