<?php

declare(strict_types=1);

namespace App\Modules\Accounts;

use App\Support\ApplicationKeys;

/**
 * A one-way fingerprint of an E.164 phone (`DL-96` item 1): HMAC-SHA256 under a
 * key derived from the application key for this one purpose. Without that key
 * the fingerprint does not give the number back, though few numbers exist.
 */
final class PhoneFingerprint
{
    private const PURPOSE = 'phone-fingerprint/v1';

    public static function of(string $phone): string
    {
        return self::under($phone, ApplicationKeys::current());
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

        foreach (ApplicationKeys::previous() as $key) {
            $candidates[] = self::under($phone, $key);
        }

        return $candidates;
    }

    private static function under(string $phone, string $applicationKey): string
    {
        return hash_hmac('sha256', $phone, hash_hmac('sha256', self::PURPOSE, $applicationKey, true));
    }
}
