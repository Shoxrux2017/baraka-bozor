<?php

declare(strict_types=1);

namespace App\Modules\Settings;

use App\Models\Enums\ServiceFeeMode;
use App\Support\Money\MoneyCalculator;
use App\Support\Money\Percentage;
use LogicException;

/**
 * The service fee on a merchandise subtotal (`BR-MONEY-005`): the fixed
 * amount, or the percentage of the subtotal rounded half up to 1 UZS. Built
 * from the settings for a checkout and from an order's snapshot for its final
 * amount, so both apply the rule the same way.
 */
final readonly class ServiceFeeCalculator
{
    public function __construct(
        private ServiceFeeMode $mode,
        private ?int $fixedUzs,
        private ?string $percent,
    ) {}

    public function feeOn(int $merchandiseSubtotalUzs): int
    {
        return match ($this->mode) {
            ServiceFeeMode::Fixed => $this->fixedUzs ?? throw new LogicException('A fixed fee needs its amount.'),
            ServiceFeeMode::Percentage => MoneyCalculator::percentOf(
                $merchandiseSubtotalUzs,
                Percentage::fromString($this->percent ?? throw new LogicException('A percentage fee needs its percentage.')),
            ),
        };
    }
}
