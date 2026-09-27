<?php

declare(strict_types=1);

namespace App\Modules\Orders\Checkout;

use App\Models\Enums\PaymentMethod;

/**
 * What a valid checkout token says: the cart, the address, the payment method
 * and the delivery wish to check out with, and the digest of the state the
 * Customer was shown. Order creation rebuilds the state from these and
 * compares the digest.
 */
final readonly class CheckoutClaims
{
    public function __construct(
        public string $cartId,
        public string $addressId,
        public PaymentMethod $paymentMethod,
        public ?string $deliveryTimeNote,
        public string $digest,
    ) {}
}
