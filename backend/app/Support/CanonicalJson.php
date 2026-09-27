<?php

declare(strict_types=1);

namespace App\Support;

use InvalidArgumentException;

/**
 * JSON that is the same for the same data however it was assembled: object
 * keys sorted at every depth, lists left in their order, no escaping of
 * slashes or non-ASCII text, and a float keeps its fraction. What an
 * idempotency key and a checkout token bind is hashed from this.
 *
 * Only scalars, nulls and arrays: an object — a model above all — would hash
 * whatever it holds at the time, so it is refused.
 */
final class CanonicalJson
{
    public static function encode(mixed $value): string
    {
        return json_encode(
            self::canonical($value),
            JSON_UNESCAPED_SLASHES | JSON_UNESCAPED_UNICODE | JSON_PRESERVE_ZERO_FRACTION | JSON_THROW_ON_ERROR
        );
    }

    public static function sha256(mixed $value): string
    {
        return hash('sha256', self::encode($value));
    }

    private static function canonical(mixed $value): mixed
    {
        if (is_object($value)) {
            throw new InvalidArgumentException('Canonical JSON holds scalars, nulls and arrays only.');
        }

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
