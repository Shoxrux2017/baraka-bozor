<?php

declare(strict_types=1);

namespace App\Modules\Settings;

use App\Models\BusinessSettings;
use App\Support\Money\MoneyCalculator;
use App\Support\Money\Percentage;

/**
 * The price a Customer sees: the market price plus the markup, rounded half
 * up to 1 UZS (`BR-PRICE-001`). Computed on every read and never stored on the
 * product (`DL-17` (3)), so a markup change reaches the whole catalog at once.
 *
 * Built once per request from the current settings, then applied to as many
 * products as the response carries.
 */
final class CustomerPriceCalculator
{
    public function __construct(private readonly Percentage $markup) {}

    public static function current(): self
    {
        return new self(Percentage::fromString(BusinessSettings::current()->markup_percent));
    }

    public function priceOf(int $marketPriceUzs): int
    {
        return MoneyCalculator::increaseByPercent($marketPriceUzs, $this->markup);
    }
}
