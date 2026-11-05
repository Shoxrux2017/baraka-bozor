<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Resources;

use App\Modules\Orders\EditPreview;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * The preview of an order edit, `docs/09` section 21, `DL-132` (1).
 *
 * @property-read EditPreview $resource
 */
final class EditPreviewResource extends JsonResource
{
    public function __construct(EditPreview $preview)
    {
        parent::__construct($preview);
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'merchandise_subtotal_uzs' => $this->resource->merchandiseSubtotalUzs,
            'service_fee_uzs' => $this->resource->serviceFeeUzs,
            'delivery_fee_uzs' => $this->resource->deliveryFeeUzs,
            'total_uzs' => $this->resource->totalUzs,
            'total_kind' => $this->resource->totalKind,
            'total_before_uzs' => $this->resource->totalBeforeUzs,
            'total_change_uzs' => $this->resource->totalChangeUzs,
            'minimum_order_uzs' => $this->resource->minimumOrderUzs,
            'minimum_order_shortfall_uzs' => $this->resource->minimumOrderShortfallUzs,
        ];
    }
}
