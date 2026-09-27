<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Models\Enums\PaymentMethod;
use App\Models\User;
use App\Modules\Orders\Checkout\CheckoutPreview;
use App\Modules\Orders\Checkout\CheckoutState;
use App\Modules\Orders\Checkout\CheckoutToken;
use App\Modules\Orders\CustomerCart;

/**
 * `POST /customer/checkout/preview` (`docs/09` section 18): checks the
 * checkout, shows its lines and amounts, and signs them into a token valid for
 * five minutes. It locks nothing and changes nothing but the cart it creates
 * on first access; order creation checks everything again under the cart lock.
 */
final class PreviewCheckout
{
    public function preview(User $customer, string $addressId, PaymentMethod $paymentMethod, ?string $deliveryTimeNote): CheckoutPreview
    {
        $now = now();
        $state = CheckoutState::gather($customer, CustomerCart::of($customer), $addressId, $paymentMethod, $deliveryTimeNote);

        return new CheckoutPreview($state, CheckoutToken::issue($state, $now), $state->isOutsideWorkingHours($now));
    }
}
