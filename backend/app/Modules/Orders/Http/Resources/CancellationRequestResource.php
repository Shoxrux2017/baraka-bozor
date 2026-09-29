<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Resources;

use App\Models\OrderCancellationRequest;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A cancellation request as the Operator and the Admin see it (`docs/09`
 * section 40, `DL-65` (4)): its order, where it came from and why, who filed
 * it and when, and who decided it, when and with what note. The board's
 * order lists its requests with `fields()`, without the order.
 *
 * Expects `order`, `requestedBy` and `resolvedBy` loaded.
 *
 * @property-read OrderCancellationRequest $resource
 */
final class CancellationRequestResource extends JsonResource
{
    public function __construct(OrderCancellationRequest $request)
    {
        parent::__construct($request);
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $cancellation = $this->resource;
        $fields = self::fields($cancellation);

        return [
            'id' => $fields['id'],
            'order' => [
                'id' => $cancellation->order->id,
                'order_number' => $cancellation->order->order_number,
                'status' => $cancellation->order->status->value,
            ],
        ] + $fields;
    }

    /**
     * The request's own fields.
     *
     * @return array<string, mixed>
     */
    public static function fields(OrderCancellationRequest $cancellation): array
    {
        return [
            'id' => $cancellation->id,
            'origin' => $cancellation->origin->value,
            'status' => $cancellation->status->value,
            'reason' => $cancellation->reason,
            'requested_by' => ['id' => $cancellation->requestedBy->id, 'full_name' => $cancellation->requestedBy->full_name],
            'created_at' => $cancellation->created_at->toIso8601ZuluString(),
            'resolved_by' => $cancellation->resolvedBy === null ? null : [
                'id' => $cancellation->resolvedBy->id,
                'full_name' => $cancellation->resolvedBy->full_name,
            ],
            'resolved_at' => $cancellation->resolved_at?->toIso8601ZuluString(),
            'resolution_note' => $cancellation->resolution_note,
        ];
    }
}
