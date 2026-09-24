<?php

declare(strict_types=1);

namespace App\Modules\Auth;

use RuntimeException;

/**
 * The configured test phone numbers of `docs/07-architecture.md` Section 8:
 * they receive no code and verify with one fixed code. How the Owner and
 * app-store reviewers sign in before a real provider exists.
 *
 * Read from `config/login_codes.php`, which is server configuration and never
 * an Admin setting (`DL-7`). The list is empty in production.
 */
final class TestPhones
{
    public const CHANNEL = 'test';

    /**
     * @param  list<string>  $phones
     */
    public function __construct(
        private readonly array $phones,
        private readonly ?string $code,
    ) {
        if ($this->phones !== [] && ($this->code === null || ! LoginCodePolicy::isWellFormed($this->code))) {
            // Loud at boot rather than a mystery at the first login attempt.
            throw new RuntimeException(
                'LOGIN_CODE_TEST_PHONES is set but LOGIN_CODE_TEST_CODE is not a '.LoginCodePolicy::DIGITS.'-digit code.'
            );
        }
    }

    public static function fromConfig(): self
    {
        $phones = config('login_codes.test_phones');
        $code = config('login_codes.test_code');

        /** @var list<string> $phones */
        $phones = is_array($phones) ? array_values(array_map('strval', $phones)) : [];

        return new self($phones, is_string($code) && $code !== '' ? $code : null);
    }

    /**
     * The fixed code for a test phone, or null for every other phone.
     */
    public function codeFor(string $phone): ?string
    {
        return in_array($phone, $this->phones, true) ? $this->code : null;
    }
}
