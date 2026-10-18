<?php

declare(strict_types=1);

namespace App\Support\Idempotency;

/**
 * A key that completed before, as `IdempotencyStore::begin()` returns it: the
 * resource its operation produced, or the answer it stored (`runAnswer()`).
 */
final readonly class Replay
{
    /**
     * @param  array<array-key, mixed>|null  $answer
     */
    public function __construct(
        public ?string $resourceId,
        public ?array $answer = null,
    ) {}
}
