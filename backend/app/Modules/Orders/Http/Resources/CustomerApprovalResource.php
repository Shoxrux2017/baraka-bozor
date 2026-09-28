<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Resources;

use App\Models\CustomerApproval;
use App\Modules\Orders\ApprovalExpiry;
use App\Modules\Orders\QuantityPolicy;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A question as its Customer sees it (`docs/09` section 23, `DL-59` (1)): the
 * order and the line it is about, what is proposed in the Customer's prices —
 * a price, a replacement with its price, or a smaller quantity — the
 * Shopper's note, and until when the Customer may answer. Never the market
 * price the Shopper paid (`BR-PRICE-001`). An approval past its expiry reads
 * as `expired` (`DL-54` (8)).
 *
 * Expects `order` and `item` loaded.
 *
 * @property-read CustomerApproval $resource
 */
final class CustomerApprovalResource extends JsonResource
{
    public function __construct(CustomerApproval $approval)
    {
        parent::__construct($approval);
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return self::fields($this->resource);
    }

    /**
     * The fields, shared with the Customer's order, which shows a line's open
     * question in the same shape.
     *
     * @return array<string, mixed>
     */
    public static function fields(CustomerApproval $approval): array
    {
        $line = $approval->item;

        return [
            'id' => $approval->id,
            'order_id' => $approval->order_id,
            'order_number' => $approval->order->order_number,
            'type' => $approval->type->value,
            'status' => ApprovalExpiry::shownStatus($approval)->value,
            'item' => [
                'id' => $line->id,
                'name_uz' => $line->product_name_uz_snapshot,
                'name_ru' => $line->product_name_ru_snapshot,
                'unit_code' => $line->unit_code_snapshot->value,
                'price_mode' => $line->price_mode_snapshot->value,
                'quantity' => QuantityPolicy::format($line->unit_code_snapshot, $line->ordered_quantity),
                'customer_unit_price_uzs' => $line->customer_unit_price_uzs_snapshot,
            ],
            'proposed_customer_unit_price_uzs' => $approval->proposed_customer_unit_price_uzs,
            'proposed_quantity' => $approval->proposed_quantity === null
                ? null
                : QuantityPolicy::format($line->unit_code_snapshot, $approval->proposed_quantity),
            'replacement' => $approval->replacement_product_id === null ? null : [
                'name_uz' => $approval->replacement_name_uz_snapshot,
                'name_ru' => $approval->replacement_name_ru_snapshot,
                'customer_unit_price_uzs' => $approval->proposed_customer_unit_price_uzs,
            ],
            'request_note' => $approval->request_note,
            'expires_at' => $approval->expires_at->toIso8601ZuluString(),
            'resolved_at' => $approval->resolved_at?->toIso8601ZuluString(),
            'created_at' => $approval->created_at->toIso8601ZuluString(),
        ];
    }
}
