<?php

declare(strict_types=1);

namespace App\Modules\Staff;

/**
 * The server-generated temporary password of `BR-ROLE-005` (`DL-17` (8)):
 * twelve characters from an alphabet without look-alikes (no `0 O o 1 I l`),
 * drawn with `random_int`, so an Admin can read it out over the phone. Fifty-
 * six symbols over twelve places is about 69 bits.
 *
 * It is returned once, in the response that created it, and never logged or
 * stored in plain text; the holder must change it at the first login.
 */
final class TemporaryPassword
{
    public const ALPHABET = '23456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz';

    public const LENGTH = 12;

    public static function generate(): string
    {
        $last = strlen(self::ALPHABET) - 1;
        $password = '';

        for ($i = 0; $i < self::LENGTH; $i++) {
            $password .= self::ALPHABET[random_int(0, $last)];
        }

        return $password;
    }
}
