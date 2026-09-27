<?php

declare(strict_types=1);

namespace App\Support\Idempotency;

/**
 * A key this request owns, as `IdempotencyStore::begin()` returns it: the row
 * and the token that proves the ownership.
 */
final readonly class Attempt
{
    public function __construct(
        public string $id,
        public string $attemptToken,
    ) {}
}
