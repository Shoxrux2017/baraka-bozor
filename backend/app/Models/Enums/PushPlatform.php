<?php

declare(strict_types=1);

namespace App\Models\Enums;

/**
 * Where a push token came from (`08` Section 25). The web panel may register
 * one too; whether it ever does is a notification-task question, not a schema
 * one.
 */
enum PushPlatform: string
{
    case Android = 'android';
    case Ios = 'ios';
    case Web = 'web';
}
