<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Push;

/**
 * What a push provider answered: delivered, refused for good, or worth
 * another try. A retry may carry the provider's `Retry-After` seconds; a
 * rejected token also asks for its device to be revoked.
 */
final readonly class PushSendResult
{
    private function __construct(
        public bool $sent,
        public bool $retryable,
        public ?string $errorCode,
        public bool $revokesDevice = false,
        public ?int $retryAfterSeconds = null,
    ) {}

    public static function sent(): self
    {
        return new self(true, false, null);
    }

    public static function failed(string $errorCode): self
    {
        return new self(false, false, $errorCode);
    }

    public static function retry(string $errorCode, ?int $retryAfterSeconds = null): self
    {
        return new self(false, true, $errorCode, false, $retryAfterSeconds);
    }

    /**
     * The provider refused the token for good: the device is revoked.
     */
    public static function rejectedToken(string $errorCode): self
    {
        return new self(false, false, $errorCode, true);
    }
}
