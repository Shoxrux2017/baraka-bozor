<?php

declare(strict_types=1);

namespace App\Support;

use LogicException;

/**
 * The raw bytes of the application key and of the keys it replaced, for the
 * purposes that derive their own keys from it (`DL-41` (7), `DL-96` item 1).
 *
 * A key that cannot be read fails closed: an empty or undecodable key throws
 * rather than yielding an empty key, which anyone could forge.
 */
final class ApplicationKeys
{
    public static function current(): string
    {
        return self::decode((string) config('app.key'));
    }

    /**
     * @return list<string>
     */
    public static function previous(): array
    {
        $keys = [];

        foreach ((array) config('app.previous_keys', []) as $key) {
            $keys[] = self::decode((string) $key);
        }

        return $keys;
    }

    private static function decode(string $key): string
    {
        if (str_starts_with($key, 'base64:')) {
            $key = base64_decode(substr($key, 7), true);
            if ($key === false) {
                throw new LogicException('The application key is not valid base64.');
            }
        }

        if ($key === '') {
            throw new LogicException('The application key is not set.');
        }

        return $key;
    }
}
