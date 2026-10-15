<?php

declare(strict_types=1);

namespace App\Modules\Auth\Actions;

use DateTimeImmutable;

/**
 * The outcome of a verified Customer login code: the Customer session and,
 * when the phone also holds a Shopper or Courier account, the single-use
 * staff step for `POST /auth/staff/step` (`DL-77`).
 */
final class VerifiedLogin
{
    public function __construct(
        public readonly IssuedSession $customer,
        #[\SensitiveParameter] public readonly ?string $staffStepToken,
        public readonly ?DateTimeImmutable $staffStepExpiresAt,
    ) {}
}
