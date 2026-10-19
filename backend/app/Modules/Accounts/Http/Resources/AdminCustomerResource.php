<?php

declare(strict_types=1);

namespace App\Modules\Accounts\Http\Resources;

use App\Models\User;
use App\Modules\Accounts\UnfinishedOrders;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * A Customer account as the Admin finds it by phone (`docs/09` Section 66),
 * with the unfinished order that would refuse its erasure.
 *
 * Expects the `orders_count` the controller loads.
 *
 * @property-read User $resource
 */
final class AdminCustomerResource extends JsonResource
{
    public function __construct(User $customer)
    {
        parent::__construct($customer);
    }

    /**
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        $customer = $this->resource;
        $unfinished = UnfinishedOrders::oldest($customer);

        return [
            'id' => $customer->id,
            'phone' => $customer->phone,
            'full_name' => $customer->full_name,
            'status' => $customer->status->value,
            'created_at' => $customer->created_at->toIso8601ZuluString(),
            'last_login_at' => $customer->last_login_at?->toIso8601ZuluString(),
            'order_count' => (int) $customer->getAttribute('orders_count'),
            'unfinished_order' => $unfinished === null
                ? null
                : ['id' => $unfinished->id, 'order_number' => $unfinished->order_number],
        ];
    }
}
