<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Cart;
use App\Models\CustomerAddress;
use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\CancellationReason;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\PaymentMethod;
use App\Models\Enums\ServiceFeeMode;
use App\Models\Order;
use App\Models\OrderShopperAssignment;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Builds an order the database accepts in any of its nine states, for the
 * tests of this wave and the next: a cash order placed from the Customer's own
 * converted cart to the Customer's own address, under a 15 % markup, a fixed
 * service fee of 5 000 and a delivery fee of 15 000.
 *
 * The states set what each status implies (`orders_*_check`) and, where a
 * status implies a Shopper, create the assignment. Items are not created: a
 * test that needs lines says which with `OrderItem::factory()`.
 *
 * @extends Factory<Order>
 */
final class OrderFactory extends Factory
{
    protected $model = Order::class;

    /** The final amounts a shopped order carries: 100 000 + 5 000 + 15 000. */
    private const SHOPPED = [
        'final_merchandise_subtotal_uzs' => 100000,
        'final_service_fee_uzs' => 5000,
        'final_total_uzs' => 120000,
    ];

    /**
     * @return array<string, mixed>
     */
    public function definition(): array
    {
        return [
            'customer_id' => User::factory()->customer(),
            'source_cart_id' => fn (array $attributes): string => Cart::factory()->converted()
                ->create(['customer_id' => $attributes['customer_id']])->id,
            'source_address_id' => fn (array $attributes): string => CustomerAddress::factory()
                ->create(['customer_id' => $attributes['customer_id']])->id,
            'status' => OrderStatus::New,
            'payment_method' => PaymentMethod::Cash,
            'delivery_time_note' => null,
            'recipient_name_snapshot' => 'Aziza Karimova',
            'recipient_phone_snapshot' => fn (array $attributes): string => User::query()
                ->findOrFail($attributes['customer_id'])->phone,
            'latitude_snapshot' => '41.311081',
            'longitude_snapshot' => '69.240562',
            'street_snapshot' => 'Amir Temur shoh ko\'chasi',
            'house_snapshot' => '12',
            'apartment_snapshot' => null,
            'landmark_snapshot' => null,
            'delivery_note_snapshot' => null,
            'markup_percent_snapshot' => '15.00',
            'price_tolerance_percent_snapshot' => '15.00',
            'service_fee_mode_snapshot' => ServiceFeeMode::Fixed,
            'service_fee_fixed_uzs_snapshot' => 5000,
            'service_fee_percent_snapshot' => null,
            'delivery_fee_uzs_snapshot' => 15000,
            'delivery_delay_threshold_minutes_snapshot' => 60,
        ];
    }

    public function online(): self
    {
        return $this->state(fn (): array => ['payment_method' => PaymentMethod::Online]);
    }

    public function shoppingAssigned(): self
    {
        return $this->state(fn (): array => ['status' => OrderStatus::ShoppingAssigned])
            ->withShopper(OrderShopperAssignment::factory());
    }

    public function shopping(): self
    {
        return $this->state(fn (): array => [
            'status' => OrderStatus::Shopping,
            'shopping_started_at' => now(),
        ])->withShopper(OrderShopperAssignment::factory()->started());
    }

    public function finalPaymentPending(): self
    {
        return $this->online()->shopped(OrderStatus::FinalPaymentPending);
    }

    public function readyForDelivery(): self
    {
        return $this->shopped(OrderStatus::ReadyForDelivery, ['ready_for_delivery_at' => now()]);
    }

    public function deliveryAssigned(): self
    {
        return $this->shopped(OrderStatus::DeliveryAssigned, ['ready_for_delivery_at' => now()]);
    }

    public function onTheWay(): self
    {
        return $this->shopped(OrderStatus::OnTheWay, ['ready_for_delivery_at' => now(), 'on_the_way_at' => now()]);
    }

    public function completed(): self
    {
        return $this->shopped(OrderStatus::Completed, [
            'ready_for_delivery_at' => now(),
            'on_the_way_at' => now(),
            'completed_at' => now(),
        ]);
    }

    public function cancelled(CancellationReason $reason = CancellationReason::CustomerCancelled): self
    {
        return $this->state(fn (): array => [
            'status' => OrderStatus::Cancelled,
            'cancelled_at' => now(),
            'cancellation_reason_code' => $reason,
        ]);
    }

    /**
     * A status after shopping: shopping started and completed, the final
     * amounts stored, and the Shopper's assignment ended as completed.
     *
     * @param  array<string, mixed>  $more
     */
    private function shopped(OrderStatus $status, array $more = []): self
    {
        return $this->state(fn (): array => array_merge([
            'status' => $status,
            'shopping_started_at' => now(),
            'shopping_completed_at' => now(),
        ], self::SHOPPED, $more))->withShopper(OrderShopperAssignment::factory()->ended(AssignmentEndReason::Completed));
    }

    private function withShopper(OrderShopperAssignmentFactory $assignment): self
    {
        return $this->afterCreating(function (Order $order) use ($assignment): void {
            $assignment->create(['order_id' => $order->id]);
        });
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    public function newModel(array $attributes = []): Order
    {
        return (new Order)->forceFill($attributes);
    }
}
