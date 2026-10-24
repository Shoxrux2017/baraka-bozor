<?php

declare(strict_types=1);

namespace App\Modules\Auth;

/**
 * The Customer login-code policy of `docs/09-api-contracts.md` Section 6,
 * in one place so the request action, the verify action and the tests agree
 * to the digit.
 */
final class LoginCodePolicy
{
    public const DIGITS = 6;

    public const LIFETIME_SECONDS = 300;

    public const MAX_FAILED_ATTEMPTS = 3;

    public const LOCK_SECONDS = 60;

    public const SENDS_PER_HOUR = 5;

    public const HOUR_SECONDS = 3600;

    /**
     * Exactly six digits. `\z`, not `$`: `$` also matches before a trailing
     * newline, which a client can send and which nothing after validation
     * expects.
     */
    public const CODE_PATTERN = '/^[0-9]{6}\z/';

    /**
     * An Uzbekistan mobile number in E.164, docs/09 Section 6, anchored the
     * same way and for the same reason.
     */
    public const PHONE_PATTERN = '/^\+998[0-9]{9}\z/';

    /**
     * The rate-limiter key holding the lock of a phone after its third wrong
     * code (`DL-87`, `DL-88`).
     */
    public static function lockKey(string $phone): string
    {
        return "login-code:lock:{$phone}";
    }

    public static function isWellFormed(#[\SensitiveParameter] string $code): bool
    {
        return preg_match(self::CODE_PATTERN, $code) === 1;
    }

    /**
     * Six identical digits, or each digit one more than the one before, or one
     * less: a fixed code that anyone would try first (`DL-105`).
     */
    public static function isGuessable(#[\SensitiveParameter] string $code): bool
    {
        $digits = array_map('intval', str_split($code));
        $steps = [];

        for ($i = 1; $i < count($digits); $i++) {
            $steps[] = $digits[$i] - $digits[$i - 1];
        }

        return count(array_unique($steps)) === 1 && in_array($steps[0] ?? null, [0, 1, -1], true);
    }
}
