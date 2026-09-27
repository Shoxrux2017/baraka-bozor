<?php

declare(strict_types=1);

namespace App\Modules\Orders\Checkout;

/**
 * A checkout the Customer may confirm: its state, the token that binds it,
 * and whether it falls outside the working hours (`BR-CHK-009`).
 */
final readonly class CheckoutPreview
{
    public function __construct(
        public CheckoutState $state,
        public IssuedCheckoutToken $token,
        public bool $outsideWorkingHours,
    ) {}
}
