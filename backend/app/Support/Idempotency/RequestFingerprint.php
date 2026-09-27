<?php

declare(strict_types=1);

namespace App\Support\Idempotency;

/**
 * The request hash an idempotency key is bound to (`DL-37` (5)): SHA-256 over
 * the canonical JSON of the operation, the route parameters and the validated
 * body. The route parameters are in it so that one key sent to cancel two
 * different orders — the same operation, the same empty body — is a key
 * reused, not a replay of the first cancellation.
 *
 * Canonical means object keys sorted at every depth, lists left in their
 * order, and no escaping of slashes or non-ASCII text, so the same request
 * hashes the same however its JSON was written.
 */
final class RequestFingerprint
{
    /**
     * @param  array<string, mixed>  $routeParameters
     * @param  array<string, mixed>  $body
     */
    public static function of(string $operation, array $routeParameters, array $body): string
    {
        $canonical = self::canonical([
            'operation' => $operation,
            'route' => $routeParameters,
            'body' => $body,
        ]);

        return hash('sha256', json_encode(
            $canonical,
            JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PRESERVE_ZERO_FRACTION | JSON_THROW_ON_ERROR
        ));
    }

    private static function canonical(mixed $value): mixed
    {
        if (! is_array($value)) {
            return $value;
        }

        $value = array_map(self::canonical(...), $value);

        if (! array_is_list($value)) {
            ksort($value, SORT_STRING);
        }

        return $value;
    }
}
