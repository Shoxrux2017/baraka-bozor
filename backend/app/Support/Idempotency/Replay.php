<?php

declare(strict_types=1);

namespace App\Support\Idempotency;

/**
 * A key that completed before, as `IdempotencyStore::begin()` returns it: the
 * resource its operation produced.
 */
final readonly class Replay
{
    public function __construct(
        public string $resourceId,
    ) {}
}
