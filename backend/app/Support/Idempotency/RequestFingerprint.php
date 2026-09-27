<?php

declare(strict_types=1);

namespace App\Support\Idempotency;

use App\Support\CanonicalJson;

/**
 * The request hash an idempotency key is bound to (`DL-37` (5)): SHA-256 over
 * the canonical JSON of the operation, the route parameters and the validated
 * body. The route parameters are in it so that one key sent to cancel two
 * different orders — the same operation, the same empty body — is a key
 * reused, not a replay of the first cancellation.
 *
 * The JSON is canonical (`CanonicalJson`), so the same request hashes the
 * same however its JSON was written, and an object anywhere in it is refused,
 * since a bound model would hash its current attributes and make a retry
 * after a change look reused. Route parameters are ids and enum values,
 * compared in lower case, so one id in either case is one request.
 */
final class RequestFingerprint
{
    /**
     * @param  array<string, string>  $routeParameters
     * @param  array<string, mixed>  $body
     */
    public static function of(string $operation, array $routeParameters, array $body): string
    {
        return CanonicalJson::sha256([
            'operation' => $operation,
            'route' => array_map(strtolower(...), $routeParameters),
            'body' => $body,
        ]);
    }
}
