<?php

declare(strict_types=1);

namespace App\Modules\Auth;

use RuntimeException;

/**
 * The phone numbers that sign in without a delivered code
 * (`docs/07-architecture.md` Section 8), of two kinds:
 *
 * - test phones: verify with one fixed code, for the Owner and development.
 *   Empty in production, where the boot refuses any (`DL-11`);
 * - the store reviewer's phone: the one exception allowed in production, with
 *   a fixed code of its own that differs from the test code (`DL-105`). It
 *   opens a Customer account only: no staff account may sit on it.
 *
 * Read from `config/login_codes.php`, which is server configuration and never
 * an Admin setting (`DL-7`). The provider resolves this at boot, so a bad
 * configuration fails the boot rather than the first login. A refusal names
 * the setting and never a value.
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
        bool $production = false,
        private readonly ?string $reviewerPhone = null,
        #[\SensitiveParameter] private readonly ?string $reviewerCode = null,
    ) {
        $this->guardReviewer();

        if ($this->phones === []) {
            return;
        }

        if ($production) {
            throw new RuntimeException('LOGIN_CODE_TEST_PHONES must be empty in production.');
        }

        if ($this->code === null || ! LoginCodePolicy::isWellFormed($this->code)) {
            throw new RuntimeException(
                'LOGIN_CODE_TEST_PHONES is set but LOGIN_CODE_TEST_CODE is not a '.LoginCodePolicy::DIGITS.'-digit code.'
            );
        }
    }

    public static function fromConfig(bool $production): self
    {
        $phones = config('login_codes.test_phones');
        $code = config('login_codes.test_code');
        $reviewerPhone = config('login_codes.reviewer_phone');
        $reviewerCode = config('login_codes.reviewer_code');

        /** @var list<string> $phones */
        $phones = is_array($phones) ? array_values(array_map('strval', $phones)) : [];

        return new self(
            $phones,
            is_string($code) && $code !== '' ? $code : null,
            $production,
            is_string($reviewerPhone) && $reviewerPhone !== '' ? $reviewerPhone : null,
            is_string($reviewerCode) && $reviewerCode !== '' ? $reviewerCode : null,
        );
    }

    /**
     * The fixed code for a test phone or the reviewer phone, or null for every
     * other phone.
     */
    public function codeFor(string $phone): ?string
    {
        if ($this->isReviewer($phone)) {
            return $this->reviewerCode;
        }

        return in_array($phone, $this->phones, true) ? $this->code : null;
    }

    public function isReviewer(string $phone): bool
    {
        return $this->reviewerPhone !== null && $phone === $this->reviewerPhone;
    }

    private function guardReviewer(): void
    {
        if ($this->reviewerPhone === null && $this->reviewerCode === null) {
            return;
        }

        if ($this->reviewerPhone === null) {
            throw new RuntimeException('LOGIN_CODE_REVIEWER_CODE is set but LOGIN_CODE_REVIEWER_PHONE is not.');
        }

        if ($this->reviewerCode === null) {
            throw new RuntimeException('LOGIN_CODE_REVIEWER_PHONE is set but LOGIN_CODE_REVIEWER_CODE is not.');
        }

        if (preg_match(LoginCodePolicy::PHONE_PATTERN, $this->reviewerPhone) !== 1) {
            throw new RuntimeException('LOGIN_CODE_REVIEWER_PHONE is not +998 followed by nine digits.');
        }

        if (! LoginCodePolicy::isWellFormed($this->reviewerCode)) {
            throw new RuntimeException(
                'LOGIN_CODE_REVIEWER_CODE is not a '.LoginCodePolicy::DIGITS.'-digit code.'
            );
        }

        if (LoginCodePolicy::isGuessable($this->reviewerCode)) {
            throw new RuntimeException('LOGIN_CODE_REVIEWER_CODE is too easy to guess.');
        }

        if ($this->reviewerCode === $this->code) {
            throw new RuntimeException('LOGIN_CODE_REVIEWER_CODE must differ from LOGIN_CODE_TEST_CODE.');
        }

        if (in_array($this->reviewerPhone, $this->phones, true)) {
            throw new RuntimeException(
                'LOGIN_CODE_REVIEWER_PHONE must not also be listed in LOGIN_CODE_TEST_PHONES.'
            );
        }
    }
}
