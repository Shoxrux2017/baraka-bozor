<?php

declare(strict_types=1);

namespace App\Exceptions;

use App\Http\Middleware\AssignRequestId;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;
use Throwable;

/**
 * Renders the BarakaBozor API error envelope for failures under the client API.
 *
 * The envelope is the stable client contract of `docs/09-api-contracts.md`
 * Section 3: `code` is what a client branches on, `message` is for developers
 * only, `errors` is always an object and holds field errors for validation
 * failures, `details` carries machine-readable values when a failure has them,
 * and `request_id` ties the response to the request's log lines. No exception
 * message, stack frame, file path, query fragment, class name or configuration
 * value ever reaches the response body, in any debug mode.
 *
 * Every failure under the client API leaves through this class. Nothing is
 * allowed to fall through to the framework renderer, because that renderer
 * echoes the exception message and, with debug enabled, a full stack trace.
 */
final class ApiExceptionRenderer
{
    /**
     * HTTP statuses that carry a stable machine code of their own.
     *
     * @var array<int, string>
     */
    private const CODE_BY_STATUS = [
        400 => 'malformed_request',
        401 => 'authentication_required',
        403 => 'forbidden',
        404 => 'resource_not_found',
        409 => 'business_conflict',
        413 => 'payload_too_large',
        422 => 'validation_failed',
        429 => 'rate_limited',
        502 => 'provider_unavailable',
        503 => 'provider_unavailable',
    ];

    private const FALLBACK_CODE = 'server_error';

    /**
     * Build the API error response, or return null for non-API requests.
     */
    public static function render(Throwable $e, Request $request): ?JsonResponse
    {
        if (! self::isApiRequest($request)) {
            return null;
        }

        if ($e instanceof ApiException) {
            return self::respond($request, $e->status(), $e->apiCode(), details: $e->details(), headers: $e->headers());
        }

        if ($e instanceof ValidationException) {
            return self::respond($request, 422, errors: $e->errors());
        }

        if ($e instanceof AuthenticationException) {
            return self::respond($request, 401);
        }

        if ($e instanceof HttpExceptionInterface) {
            $status = self::normalizeStatus($e->getStatusCode());

            // Headers such as Retry-After and X-RateLimit-* are part of the
            // client contract for the status that produced them. They are kept
            // only when the status survives normalization, so that a remapped
            // response cannot carry a header describing the original one.
            $headers = $status === $e->getStatusCode() ? $e->getHeaders() : [];

            // Planned downtime is not a provider failure. The maintenance
            // middleware throws a bare 503, so the mode itself is what
            // distinguishes the two; the client acts the same either way.
            $code = $status === 503 && app()->isDownForMaintenance() ? 'service_unavailable' : null;

            return self::respond($request, $status, $code, headers: $headers);
        }

        return self::respond($request, 500);
    }

    /**
     * Map a status with no machine code of its own onto one that has.
     *
     * A client error outside the table becomes a scope-safe 404: the answer for
     * "what you asked for is not there in that form", and the one that reveals
     * least — a 405 would otherwise disclose, through its status and its Allow
     * header, which methods a path accepts. A server error keeps its status and
     * carries `server_error`.
     */
    /**
     * Whether the request is for the API, decided on the raw path. The
     * framework's `is('api/*')` matches the decoded path with a UTF-8 pattern,
     * which fails on a path that is not UTF-8 — exactly the request whose
     * `400` must still be answered as an API error (`DL-24`).
     */
    public static function isApiRequest(Request $request): bool
    {
        return str_starts_with($request->getPathInfo(), '/api/');
    }

    private static function normalizeStatus(int $status): int
    {
        if (isset(self::CODE_BY_STATUS[$status])) {
            return $status;
        }

        return $status >= 500 ? $status : 404;
    }

    /**
     * @param  array<string, array<int, string>>  $errors
     * @param  array<string, mixed>  $details
     * @param  array<string, string>  $headers
     */
    private static function respond(
        Request $request,
        int $status,
        ?string $code = null,
        array $errors = [],
        array $details = [],
        array $headers = [],
    ): JsonResponse {
        $body = [
            'message' => self::message($status),
            'code' => $code ?? self::CODE_BY_STATUS[$status] ?? self::FALLBACK_CODE,
            'errors' => (object) $errors,
        ];

        if ($details !== []) {
            $body['details'] = $details;
        }

        $body['request_id'] = self::requestId($request);

        return new JsonResponse($body, $status, $headers);
    }

    /**
     * The identifier the middleware assigned, or a fresh one when the failure
     * happened before any middleware ran (a bootstrap failure, or a unit
     * test), so that no error response ever lacks one.
     */
    private static function requestId(Request $request): string
    {
        $assigned = $request->attributes->get(AssignRequestId::ATTRIBUTE);

        return is_string($assigned) && $assigned !== '' ? $assigned : AssignRequestId::generate();
    }

    /**
     * Fixed, non-revealing text. Clients branch on `code`, never on this.
     */
    private static function message(int $status): string
    {
        return match ($status) {
            400 => 'The request could not be parsed.',
            401 => 'Authentication is required.',
            403 => 'This action is not allowed.',
            404 => 'The requested resource was not found.',
            409 => 'The request conflicts with the current state.',
            413 => 'The request body is too large.',
            422 => 'The given data was invalid.',
            429 => 'Too many requests.',
            502, 503 => 'The service or an external provider is temporarily unavailable.',
            default => 'An unexpected server error occurred.',
        };
    }
}
