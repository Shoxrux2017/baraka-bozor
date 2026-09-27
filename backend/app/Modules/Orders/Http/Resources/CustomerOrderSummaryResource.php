<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Resources;

use App\Models\Enums\OrderItemStatus;
use App\Models\Order;
use App\Models\OrderItem;
use App\Modules\Orders\OrderTotals;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * An order in the Customer's list (`docs/09` section 20, `DL-42`): enough to
 * find it and see where it stands — the number, the status, the payment
 * method, how many lines, the total and its kind, when it was placed. The
 * detail carries the rest.
 *
 * Expects `items` loaded.
 *
 * @property-read Order $resource
 */
final class CustomerOrderSummaryResource extends JsonResource
{
    public function __construct(Order $order)
    {
        parent::__construct($order);
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $order = $this->resource;
        $totals = OrderTotals::of($order, $order->items);

        return [
            'id' => $order->id,
            'order_number' => $order->order_number,
            'status' => $order->status->value,
            'payment_method' => $order->payment_method->value,
            'item_count' => $order->items->filter(
                static fn (OrderItem $item): bool => $item->status !== OrderItemStatus::Removed
            )->count(),
            'total_uzs' => $totals->totalUzs,
            'total_kind' => $totals->kind,
            'created_at' => $order->created_at->toIso8601ZuluString(),
        ];
    }
}
