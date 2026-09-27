<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Resources;

use App\Modules\Orders\CartLine;
use App\Modules\Orders\Checkout\CheckoutPreview;
use App\Modules\Orders\QuantityPolicy;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * The checkout preview of `docs/09` section 18: the lines at the prices the
 * order would snapshot, the merchandise subtotal, the service fee, the
 * delivery fee and the total, whether the total is `final` or an `estimate`,
 * whether the order falls outside the working hours and when they open, and
 * the token that binds it all for five minutes.
 *
 * @property-read CheckoutPreview $resource
 */
final class CheckoutPreviewResource extends JsonResource
{
    public function __construct(CheckoutPreview $preview)
    {
        parent::__construct($preview);
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $state = $this->resource->state;

        return [
            'lines' => array_map(static fn (CartLine $line): array => [
                'cart_item_id' => $line->item->id,
                'product_id' => $line->product->id,
                'name_uz' => $line->product->name_uz,
                'name_ru' => $line->product->name_ru,
                'unit_code' => $line->product->unit_code->value,
                'quantity' => QuantityPolicy::format($line->product->unit_code, $line->item->quantity),
                'price_mode' => $line->product->price_mode->value,
                'customer_unit_price_uzs' => $line->customerUnitPriceUzs,
                'line_total_uzs' => $line->estimatedLineTotalUzs,
            ], $state->lines),
            'merchandise_subtotal_uzs' => $state->merchandiseSubtotalUzs,
            'service_fee_uzs' => $state->serviceFeeUzs,
            'delivery_fee_uzs' => $state->deliveryFeeUzs,
            'total_uzs' => $state->totalUzs,
            'total_kind' => $state->totalKind(),
            'payment_method' => $state->paymentMethod->value,
            'delivery_time_note' => $state->deliveryTimeNote,
            'outside_working_hours' => $this->resource->outsideWorkingHours,
            'opens_at' => $state->hours->isAlwaysOpen() ? null : $state->hours->opensAt(),
            'checkout_token' => $this->resource->token->token,
            'checkout_token_expires_at' => $this->resource->token->expiresAt->toIso8601ZuluString(),
        ];
    }
}
