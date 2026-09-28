<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Resources;

use App\Models\Order;
use App\Models\OrderShopperAssignment;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * One order of the Shopper's list (`docs/09` section 28, `DL-56` (1)): its
 * number and status, how many lines the Shopper sees and how many are still
 * open, the delivery wish, and where the Shopper's own assignment stands.
 *
 * Expects `item_count` and `open_item_count` from
 * `ShopperOrders::withLineCounts()` and `currentShopperAssignment` loaded.
 *
 * @property-read Order $resource
 */
final class ShopperOrderSummaryResource extends JsonResource
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

        return [
            'id' => $order->id,
            'order_number' => $order->order_number,
            'status' => $order->status->value,
            'item_count' => (int) $order->getAttribute('item_count'),
            'open_item_count' => (int) $order->getAttribute('open_item_count'),
            'delivery_time_note' => $order->delivery_time_note,
            'assignment' => self::assignment($order->currentShopperAssignment),
        ];
    }

    /**
     * @return array{id: string, assigned_at: string, accepted_at: string|null, started_at: string|null}|null
     */
    public static function assignment(?OrderShopperAssignment $assignment): ?array
    {
        if ($assignment === null) {
            return null;
        }

        return [
            'id' => $assignment->id,
            'assigned_at' => $assignment->assigned_at->toIso8601ZuluString(),
            'accepted_at' => $assignment->accepted_at?->toIso8601ZuluString(),
            'started_at' => $assignment->started_at?->toIso8601ZuluString(),
        ];
    }
}
