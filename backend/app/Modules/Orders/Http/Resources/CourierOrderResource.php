<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Resources;

use App\Models\Enums\OrderStatus;
use App\Models\Enums\PaymentMethod;
use App\Models\Order;
use App\Models\OrderCourierAssignment;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * An order as its Courier sees it, in the list and alone (`docs/09` section
 * 36, `DL-54` (11), (12), `DL-63`): who receives it and where, the delivery
 * wishes, the payment method and the cash to collect, whether a cancellation
 * request is pending, and the Courier's own assignment with what may be done
 * next. Never the lines, the prices or the Customer's account.
 *
 * `shopper_phone` — the phone of the Shopper who bought the order — is there
 * only while the business runs without a handoff point
 * (`delivery.handoff_point`, `BR-DEL-006`), and absent otherwise.
 *
 * Once the Courier's assignment has ended — every answer of delivered and
 * not-delivered, the first one included — the order tells the outcome but no
 * longer who receives it, where or when: `recipient`, `address`,
 * `delivery_note` and `delivery_time_note` are `null` and `shopper_phone` is
 * absent, since the delivery is no longer the Courier's (`DL-64` (7)).
 *
 * Expects what `CourierOrders::withDetails()` loads.
 *
 * @property-read Order $resource
 */
final class CourierOrderResource extends JsonResource
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
        $assignment = $order->currentCourierAssignment;
        $pending = (bool) $order->getAttribute('cancellation_request_pending');
        $holds = $assignment !== null && $assignment->ended_at === null;

        $data = [
            'id' => $order->id,
            'order_number' => $order->order_number,
            'status' => $order->status->value,
            'recipient' => ! $holds ? null : [
                'full_name' => $order->recipient_name_snapshot,
                'phone' => $order->recipient_phone_snapshot,
            ],
            'address' => ! $holds ? null : [
                'latitude' => $order->latitude_snapshot,
                'longitude' => $order->longitude_snapshot,
                'street' => $order->street_snapshot,
                'house' => $order->house_snapshot,
                'apartment' => $order->apartment_snapshot,
                'landmark' => $order->landmark_snapshot,
            ],
            'delivery_note' => $holds ? $order->delivery_note_snapshot : null,
            'delivery_time_note' => $holds ? $order->delivery_time_note : null,
            'payment_method' => $order->payment_method->value,
            'amount_to_collect_uzs' => $order->payment_method === PaymentMethod::Cash ? $order->final_total_uzs : null,
            'cancellation_request_pending' => $pending,
            'assignment' => self::assignment($assignment),
            'can_accept' => $assignment !== null && $assignment->accepted_at === null,
            'can_start' => $assignment !== null && $assignment->accepted_at !== null && $assignment->delivery_started_at === null
                && $order->status === OrderStatus::DeliveryAssigned && ! $pending,
        ];

        if ($holds && ! config('delivery.handoff_point')) {
            $data['shopper_phone'] = $order->namedShopperAssignment?->shopper->phone;
        }

        return $data;
    }

    /**
     * @return array{id: string, assigned_at: string, accepted_at: string|null, delivery_started_at: string|null, delay_at: string|null}|null
     */
    private static function assignment(?OrderCourierAssignment $assignment): ?array
    {
        if ($assignment === null) {
            return null;
        }

        return [
            'id' => $assignment->id,
            'assigned_at' => $assignment->assigned_at->toIso8601ZuluString(),
            'accepted_at' => $assignment->accepted_at?->toIso8601ZuluString(),
            'delivery_started_at' => $assignment->delivery_started_at?->toIso8601ZuluString(),
            'delay_at' => $assignment->delay_at?->toIso8601ZuluString(),
        ];
    }
}
