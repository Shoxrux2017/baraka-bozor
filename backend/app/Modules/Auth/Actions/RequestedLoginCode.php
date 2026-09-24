<?php

declare(strict_types=1);

namespace App\Modules\Auth\Actions;

/**
 * What the client learns after asking for a login code: which channel carried
 * it and the two timers. Never the code.
 */
final class RequestedLoginCode
{
    public function __construct(
        public readonly string $channel,
        public readonly int $expiresInSeconds,
        public readonly int $resendAvailableInSeconds,
    ) {}
}
