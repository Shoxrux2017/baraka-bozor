<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Models\Enums\PaymentMethod;
use App\Models\User;
use App\Modules\Orders\Actions\PreviewCheckout;
use App\Modules\Orders\Http\Requests\CheckoutPreviewRequest;
use App\Modules\Orders\Http\Resources\CheckoutPreviewResource;

/**
 * `POST /customer/checkout/preview` (`docs/09` section 18).
 */
final class CheckoutController extends Controller
{
    public function preview(CheckoutPreviewRequest $request, PreviewCheckout $checkout): CheckoutPreviewResource
    {
        $customer = $request->user();
        if (! $customer instanceof User) {
            abort(401);
        }

        /** @var array{address_id: string, payment_method: string, delivery_time_note?: string|null} $fields */
        $fields = $request->validated();

        return new CheckoutPreviewResource($checkout->preview(
            $customer,
            $fields['address_id'],
            PaymentMethod::from($fields['payment_method']),
            $fields['delivery_time_note'] ?? null,
        ));
    }
}
