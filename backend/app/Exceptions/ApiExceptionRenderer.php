<?php

declare(strict_types=1);

namespace App\Exceptions;

use Illuminate\Auth\AuthenticationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Throwable;

/**
 * Renders the BarakaBozor API error envelope for failures under the client API.
 *
 * The envelope is the stable client contract: `code` is what a client branches
 * on, `message` is for humans only, and `errors` is always an object. No
 * exception message, stack frame, file path, query fragment, class name or
 * configuration value ever reaches the response body, in any debug mode.
 *
 * Every failure under the client API leaves through this class. Nothing is
 * allowed to fall through to the framework renderer, because that renderer
 * echoes the exception message and, with debug enabled, a full stack trace.
 */
final class ApiExceptionRenderer
{
    /**
     * HTTP statuses that carry an approved stable machine code.
     *
     * @var array<int, string>
     */
    private const CODE_BY_STATUS = [
        401 => 'authentication_required',
        403 => 'forbidden',
        404 => 'resource_not_found',
        422 => 'validation_failed',
        429 => 'rate_limited',
    ];

    private const FALLBACK_CODE = 'server_error';

    /**
     * Build the API error response, or return null for non-API requests.
     */
    public static function render(Throwable $e, Request $request): ?JsonResponse
    {
        if (! $request->is('api/*')) {
            return null;
        }

        if ($e instanceof ValidationException) {
            return self::respond(422, $e->errors());
        }

        if ($e instanceof AuthenticationException) {
            return self::respond(401);
        }

        if ($e instanceof HttpExceptionInterface) {
            $status = self::normalizeStatus($e->getStatusCode());

            // Headers such as Retry-After and X-RateLimit-* are part of the
            // client contract for the status that produced them. They are kept
            // only when the status survives normalization, so that a remapped
            // response cannot carry a header describing the original one.
            $headers = $status === $e->getStatusCode() ? $e->getHeaders() : [];

            return self::respond($status, [], $headers);
        }

        return self::respond(500);
    }

    /**
     * Map a status with no approved machine code onto one that has.
     *
     * A client error outside the approved set becomes a scope-safe 404: the
     * approved answer for "what you asked for is not there in that form", and
     * the one that reveals least, since a 405 would otherwise disclose which
     * methods a path accepts. Server errors keep their status and fall back to
     * `server_error`.
     *
     * This is interim behavior. Codes for 400, 502 and 503 are an open decision
     * recorded as S-16 in docs/SPEC_DECISIONS_BACKLOG.md, which must be resolved
     * before the first real endpoint ships.
     */
    private static function normalizeStatus(int $status): int
    {
        if (isset(self::CODE_BY_STATUS[$status])) {
            return $status;
        }

        return $status >= 500 ? $status : 404;
    }

    /**
     * @param  array<string, array<int, string>>  $errors
     * @param  array<string, string>  $headers
     */
    private static function respond(int $status, array $errors = [], array $headers = []): JsonResponse
    {
        return new JsonResponse([
            'message' => self::message($status),
            'code' => self::CODE_BY_STATUS[$status] ?? self::FALLBACK_CODE,
            'errors' => (object) $errors,
        ], $status, $headers);
    }

    /**
     * Fixed, non-revealing text. Clients branch on `code`, never on this.
     */
    private static function message(int $status): string
    {
        return match ($status) {
            401 => 'Authentication is required.',
            403 => 'This action is not allowed.',
            404 => 'The requested resource was not found.',
            422 => 'The given data was invalid.',
            429 => 'Too many requests.',
            default => 'An unexpected server error occurred.',
        };
    }
}
