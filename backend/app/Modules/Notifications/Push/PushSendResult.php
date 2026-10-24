<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Push;

/**
 * What a push provider answered: delivered, refused for good, or worth
 * another try.
 */
final readonly class PushSendResult
{
    private function __construct(
        public bool $sent,
        public bool $retryable,
        public ?string $errorCode,
    ) {}

    public static function sent(): self
    {
        return new self(true, false, null);
    }

    public static function failed(string $errorCode): self
    {
        return new self(false, false, $errorCode);
    }

    public static function retry(string $errorCode): self
    {
        return new self(false, true, $errorCode);
    }
}
