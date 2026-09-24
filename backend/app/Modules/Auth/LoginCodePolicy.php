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

    public const MAX_FAILED_ATTEMPTS = 5;

    public const RESEND_SECONDS = 60;

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

    public static function isWellFormed(string $code): bool
    {
        return preg_match(self::CODE_PATTERN, $code) === 1;
    }
}
