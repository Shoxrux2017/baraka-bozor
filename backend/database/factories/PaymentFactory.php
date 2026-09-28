<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Enums\PaymentMethod;
use App\Models\Enums\PaymentStatus;
use App\Models\Order;
use App\Models\Payment;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Builds the cash a Courier records at handover (`BR-PAY-003`): the order's
 * final total, paid, recorded by the Courier who is delivering it. An order
 * made `completed` by its factory already has this payment; on its own the
 * factory takes an order on the way, the moment before the handover.
 *
 * @extends Factory<Payment>
 */
final class PaymentFactory extends Factory
{
    protected $model = Payment::class;

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'order_id' => Order::factory()->onTheWay(),
            'method' => PaymentMethod::Cash,
            'provider' => null,
            'amount_uzs' => fn (array $attributes): int => (int) $this->order($attributes)->final_total_uzs,
            'status' => PaymentStatus::Paid,
            'attention_at' => null,
            'paid_at' => now(),
            'cancelled_at' => null,
            'recorded_by_user_id' => fn (array $attributes): ?string => $this->order($attributes)->courierAssignments()->latest('assigned_at')->first()?->courier_id,
        ];
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function order(array $attributes): Order
    {
        return Order::query()->findOrFail($attributes['order_id']);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function newModel(array $attributes = []): Payment
    {
        return (new Payment)->forceFill($attributes);
    }
}
