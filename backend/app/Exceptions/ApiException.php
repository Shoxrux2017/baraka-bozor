<?php

declare(strict_types=1);

namespace App\Exceptions;

use RuntimeException;

/**
 * A failure the API answers with a stable machine code and, optionally,
 * machine-readable values.
 *
 * Actions throw this for business and lifecycle refusals — an order that can
 * no longer be edited, a checkout below the minimum amount — instead of
 * aborting with a bare status. `docs/09-api-contracts.md` Section 3 fixes the
 * envelope: the code is what a client branches on, and a value the client
 * needs to compose its own text (the minimum amount, the shortfall) travels in
 * `details`, never inside prose.
 *
 * The message is for developers and logs only; the renderer never sends it to
 * a client, so nothing sensitive may be avoided by keeping it vague — it may
 * simply never contain anything sensitive.
 */
final class ApiException extends RuntimeException
{
    /**
     * @param  array<string, mixed>  $details
     */
    public function __construct(
        private readonly int $status,
        private readonly string $apiCode,
        private readonly array $details = [],
        string $message = '',
    ) {
        parent::__construct($message !== '' ? $message : "API failure {$status} {$apiCode}.");
    }

    /**
     * A `409` lifecycle, business, idempotency or concurrency conflict.
     *
     * @param  array<string, mixed>  $details
     */
    public static function conflict(string $apiCode, array $details = [], string $message = ''): self
    {
        return new self(409, $apiCode, $details, $message);
    }

    /**
     * A `422` refusal that is not a field validation error — a business rule
     * the whole request breaks, such as the minimum order amount.
     *
     * @param  array<string, mixed>  $details
     */
    public static function unprocessable(string $apiCode, array $details = [], string $message = ''): self
    {
        return new self(422, $apiCode, $details, $message);
    }

    /**
     * A `403` capability denial with a specific code.
     *
     * @param  array<string, mixed>  $details
     */
    public static function forbidden(string $apiCode, array $details = [], string $message = ''): self
    {
        return new self(403, $apiCode, $details, $message);
    }

    /**
     * A `401` refusal with a specific code, such as `account_blocked`.
     */
    public static function unauthenticated(string $apiCode, string $message = ''): self
    {
        return new self(401, $apiCode, [], $message);
    }

    public function status(): int
    {
        return $this->status;
    }

    public function apiCode(): string
    {
        return $this->apiCode;
    }

    /**
     * @return array<string, mixed>
     */
    public function details(): array
    {
        return $this->details;
    }
}
