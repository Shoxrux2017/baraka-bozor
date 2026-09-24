<?php

declare(strict_types=1);

namespace App\Exceptions;

use Illuminate\Contracts\Debug\ShouldntReport;
use InvalidArgumentException;
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
 * The constructor is private: every instance comes from a factory below, so
 * the API can only answer with a status the renderer's table knows. A refusal
 * is an expected outcome, not an incident, so it is not reported to the error
 * log (`ShouldntReport`); the response carries the request id for support.
 *
 * The message is for developers only; the renderer never sends it. `details`
 * reaches the client verbatim, so it is restricted to scalars and null, nested
 * in plain arrays — never a model or an object.
 */
final class ApiException extends RuntimeException implements ShouldntReport
{
    /**
     * @param  array<string, mixed>  $details
     * @param  array<string, string>  $headers
     */
    private function __construct(
        private readonly int $status,
        private readonly string $apiCode,
        private readonly array $details = [],
        string $message = '',
        private readonly array $headers = [],
    ) {
        self::assertScalarTree($details, 'details');

        parent::__construct($message !== '' ? $message : "API failure {$status} {$apiCode}.");
    }

    /**
     * A `400` request the client cannot repair by retrying, such as a missing
     * `Idempotency-Key` header.
     */
    public static function badRequest(string $apiCode, string $message = ''): self
    {
        return new self(400, $apiCode, [], $message);
    }

    /**
     * A `401` refusal with a specific code, such as `account_blocked`.
     */
    public static function unauthenticated(string $apiCode, string $message = ''): self
    {
        return new self(401, $apiCode, [], $message);
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
     * A `429` refusal with the generic code. `Retry-After` is part of the
     * contract for this status: without it a client cannot back off correctly.
     */
    public static function rateLimited(int $retryAfterSeconds, string $message = ''): self
    {
        return self::tooManyRequests('rate_limited', $retryAfterSeconds, $message);
    }

    /**
     * A `429` refusal with a specific code, such as `code_resend_too_soon`.
     */
    public static function tooManyRequests(string $apiCode, int $retryAfterSeconds, string $message = ''): self
    {
        return new self(429, $apiCode, [], $message, ['Retry-After' => (string) max(1, $retryAfterSeconds)]);
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

    /**
     * @return array<string, string>
     */
    public function headers(): array
    {
        return $this->headers;
    }

    /**
     * Refuse anything that is not a scalar, null, or a plain array of those.
     *
     * `JsonResponse` would happily serialise a model or any JsonSerializable
     * placed here, attributes and all. Failing at construction keeps that a
     * developer error caught by the first test rather than a leak in production.
     *
     * @param  array<array-key, mixed>  $values
     */
    private static function assertScalarTree(array $values, string $path): void
    {
        foreach ($values as $key => $value) {
            if (is_array($value)) {
                self::assertScalarTree($value, "{$path}.{$key}");

                continue;
            }

            if ($value !== null && ! is_scalar($value)) {
                throw new InvalidArgumentException(
                    "ApiException details may hold only scalars, null and plain arrays; {$path}.{$key} is ".get_debug_type($value).'.'
                );
            }
        }
    }
}
