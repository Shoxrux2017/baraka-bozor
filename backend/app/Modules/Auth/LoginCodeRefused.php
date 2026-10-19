<?php

declare(strict_types=1);

namespace App\Modules\Auth;

use RuntimeException;

/**
 * A login code was refused by `LoginCodeCheck`. Each purpose maps it to its own
 * answer: sign-in to `401` / `429`, account deletion to `422` / `429`, because
 * the client logs out on any `401`.
 *
 * `apiCode` is `code_invalid`, `code_expired`, `code_attempts_exhausted` or
 * `code_locked`; `retryAfterSeconds` is set only for `code_locked`.
 */
final class LoginCodeRefused extends RuntimeException
{
    public function __construct(
        public readonly string $apiCode,
        public readonly ?int $retryAfterSeconds = null,
    ) {
        parent::__construct($apiCode);
    }
}
