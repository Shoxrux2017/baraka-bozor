<?php

declare(strict_types=1);

namespace App\Modules\Accounts;

use LogicException;

/**
 * A one-way fingerprint of an E.164 phone (`DL-96` item 1): HMAC-SHA256 under a
 * dedicated secret, `PHONE_FINGERPRINT_KEY`. Without that key the fingerprint
 * does not give the number back, though few numbers exist.
 *
 * Every configured key must be `base64:` and 32 bytes; anything else throws
 * rather than yielding a key that anyone could forge.
 */
final class PhoneFingerprint
{
    private const KEY_BYTES = 32;

    public static function of(string $phone): string
    {
        return self::under($phone, self::decode(config('accounts.phone_fingerprint.key')));
    }

    /**
     * The fingerprint under the current key, then under each previous key, so a
     * rotated key keeps matching what was recorded under the old one.
     *
     * @return list<string>
     */
    public static function candidates(string $phone): array
    {
        $candidates = [self::of($phone)];

        foreach ((array) config('accounts.phone_fingerprint.previous_keys', []) as $key) {
            $candidates[] = self::under($phone, self::decode($key));
        }

        return $candidates;
    }

    private static function under(string $phone, string $key): string
    {
        return hash_hmac('sha256', $phone, $key);
    }

    private static function decode(mixed $configured): string
    {
        $key = is_string($configured) ? trim($configured) : '';

        if (! str_starts_with($key, 'base64:')) {
            throw new LogicException('The phone fingerprint key is not set or does not start with "base64:".');
        }

        $bytes = base64_decode(substr($key, 7), true);

        if ($bytes === false || strlen($bytes) !== self::KEY_BYTES) {
            throw new LogicException('The phone fingerprint key must be base64 of exactly 32 bytes.');
        }

        return $bytes;
    }
}
