<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\BusinessSettings;
use App\Models\Enums\PriceMode;
use App\Models\Enums\ServiceFeeMode;
use App\Modules\Settings\ServiceFeeCalculator;
use App\Support\Money\MoneyCalculator;

/**
 * What checkout would charge the cart now (`docs/09` section 17, `DL-85`
 * item 1): the service fee by the current rule on the subtotal of the
 * available lines, the delivery fee, their total with the subtotal, and what
 * the subtotal lacks to the minimum order. A figure whose setting is unset is
 * `null` (`BR-SET-002`), and so is the total. Checkout stays the authority.
 */
final readonly class CartCharges
{
    private function __construct(
        public ?int $serviceFeeUzs,
        public ?string $serviceFeeKind,
        public ?int $deliveryFeeUzs,
        public ?int $estimatedTotalUzs,
        public ?int $minimumOrderUzs,
        public ?int $minimumOrderShortfallUzs,
    ) {}

    public static function of(CartView $view, BusinessSettings $settings): self
    {
        $subtotal = $view->estimatedSubtotalUzs;
        $fixed = $settings->service_fee_mode === ServiceFeeMode::Fixed;
        $feeIsSet = ($fixed ? $settings->service_fee_fixed_uzs : $settings->service_fee_percent) !== null;

        $fee = $feeIsSet
            ? (new ServiceFeeCalculator(
                $settings->service_fee_mode,
                $settings->service_fee_fixed_uzs,
                $settings->service_fee_percent,
            ))->feeOn($subtotal)
            : null;
        $delivery = $settings->delivery_fee_uzs;
        $minimum = $settings->minimum_order_uzs;

        return new self(
            $fee,
            $fee === null ? null : self::kindOf($view, $fixed),
            $delivery,
            $fee === null || $delivery === null ? null : MoneyCalculator::sum($subtotal, $fee, $delivery),
            $minimum,
            $minimum === null ? null : max(0, $minimum - $subtotal),
        );
    }

    /**
     * A fixed fee is final; a percentage is an estimate while any available
     * line is priced by estimate.
     */
    private static function kindOf(CartView $view, bool $fixed): string
    {
        if ($fixed) {
            return 'final';
        }

        foreach ($view->lines as $line) {
            if ($line->available && $line->product->price_mode === PriceMode::Estimate) {
                return 'estimate';
            }
        }

        return 'final';
    }
}
