<?php

declare(strict_types=1);

namespace App\Modules\Orders;

/**
 * What an order edit would leave (`DL-132` (1), (2)): the sums by the edit's
 * own plan, the total the order has now and the signed change, the current
 * minimum and the shortfall, which is non-zero exactly when the edit would be
 * refused for the minimum. `totalKind` is `estimate` or `final`.
 */
final readonly class EditPreview
{
    public function __construct(
        public int $merchandiseSubtotalUzs,
        public int $serviceFeeUzs,
        public int $deliveryFeeUzs,
        public int $totalUzs,
        public string $totalKind,
        public int $totalBeforeUzs,
        public int $totalChangeUzs,
        public ?int $minimumOrderUzs,
        public int $minimumOrderShortfallUzs,
    ) {}
}
