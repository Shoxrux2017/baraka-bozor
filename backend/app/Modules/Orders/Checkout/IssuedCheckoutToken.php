<?php

declare(strict_types=1);

namespace App\Modules\Orders\Checkout;

use Carbon\CarbonImmutable;

/**
 * A checkout token and the instant it stops being usable.
 */
final readonly class IssuedCheckoutToken
{
    public function __construct(
        public string $token,
        public CarbonImmutable $expiresAt,
    ) {}
}
