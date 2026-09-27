<?php

declare(strict_types=1);

namespace App\Http\Middleware;

use App\Exceptions\ApiException;
use Closure;
use Illuminate\Http\Request;
use Illuminate\Validation\ValidationException;
use LogicException;
use Symfony\Component\HttpFoundation\Response;

/**
 * The `Idempotency-Key` header of `docs/09` Section 48, on the routes that
 * require it: missing is `400 idempotency_key_required`, and a value that is
 * not a UUID is `422 validation_failed` on the header (`docs/08` Section 27
 * stores the key as a UUID). The action reads the checked key with `of()`.
 */
final class RequireIdempotencyKey
{
    public const HEADER = 'Idempotency-Key';

    private const ATTRIBUTE = 'idempotency_key';

    // `D`: the end is the end, not a trailing newline before it.
    private const UUID = '/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/iD';

    /**
     * @param  Closure(Request): Response  $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $key = $request->headers->get(self::HEADER);

        if ($key === null || trim($key) === '') {
            throw ApiException::badRequest('idempotency_key_required', 'The Idempotency-Key header is required.');
        }

        if (preg_match(self::UUID, $key) !== 1) {
            throw ValidationException::withMessages([self::HEADER => 'The Idempotency-Key header must be a UUID.']);
        }

        $request->attributes->set(self::ATTRIBUTE, strtolower($key));

        return $next($request);
    }

    /**
     * The checked key of a request that passed this middleware.
     */
    public static function of(Request $request): string
    {
        $key = $request->attributes->get(self::ATTRIBUTE);

        if (! is_string($key)) {
            throw new LogicException('The route does not require an Idempotency-Key.');
        }

        return $key;
    }
}
