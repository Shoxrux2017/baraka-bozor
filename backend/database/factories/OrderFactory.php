<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Cart;
use App\Models\CustomerAddress;
use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\CancellationReason;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\PaymentMethod;
use App\Models\Enums\PaymentProvider;
use App\Models\Enums\PaymentStatus;
use App\Models\Enums\ServiceFeeMode;
use App\Models\Order;
use App\Models\OrderCourierAssignment;
use App\Models\OrderShopperAssignment;
use App\Models\Payment;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * Builds an order the database accepts in any of its nine states, for the
 * tests of this wave and the next: a cash order placed from the Customer's own
 * converted cart to the Customer's own address — the recipient and the
 * address snapshots copied from them — under a 15 % markup, a fixed service
 * fee of 5 000 and a delivery fee of 15 000.
 *
 * The states set what each status implies (`orders_*_check`) and, where a
 * status implies a Shopper or a Courier, create the assignment; a completed
 * order also has the payment its delivery recorded — the cash the Courier
 * collected, for a cash order. [cancelled] goes last and ends the current
 * assignments the way a cancellation does. Items are not created: a test that
 * needs lines says which with `OrderItem::factory()`.
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
            'recipient_name_snapshot' => fn (array $attributes): string => $this->customer($attributes)->full_name ?? 'Aziza Karimova',
            'recipient_phone_snapshot' => fn (array $attributes): string => $this->customer($attributes)->phone,
            'latitude_snapshot' => fn (array $attributes): string => $this->address($attributes)->latitude,
            'longitude_snapshot' => fn (array $attributes): string => $this->address($attributes)->longitude,
            'street_snapshot' => fn (array $attributes): string => $this->address($attributes)->street,
            'house_snapshot' => fn (array $attributes): string => $this->address($attributes)->house,
            'apartment_snapshot' => fn (array $attributes): ?string => $this->address($attributes)->apartment,
            'landmark_snapshot' => fn (array $attributes): ?string => $this->address($attributes)->landmark,
            'delivery_note_snapshot' => fn (array $attributes): ?string => $this->address($attributes)->delivery_note,
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
        return $this->shopped(OrderStatus::DeliveryAssigned, ['ready_for_delivery_at' => now()])
            ->withCourier(OrderCourierAssignment::factory());
    }

    public function onTheWay(): self
    {
        return $this->shopped(OrderStatus::OnTheWay, ['ready_for_delivery_at' => now(), 'on_the_way_at' => now()])
            ->withCourier(OrderCourierAssignment::factory()->started());
    }

    /**
     * Delivered: the Courier's assignment ended as completed, and the payment
     * recorded — the cash the Courier collected, or for an online order the
     * provider's confirmed payment.
     */
    public function completed(): self
    {
        return $this->shopped(OrderStatus::Completed, [
            'ready_for_delivery_at' => now(),
            'on_the_way_at' => now(),
            'completed_at' => now(),
        ])->afterCreating(function (Order $order): void {
            $assignment = OrderCourierAssignment::factory()->ended(AssignmentEndReason::Completed)->create(['order_id' => $order->id]);
            $online = $order->payment_method === PaymentMethod::Online;

            Payment::factory()->create([
                'order_id' => $order->id,
                'method' => $order->payment_method,
                'provider' => $online ? PaymentProvider::Payme : null,
                'amount_uzs' => $order->final_total_uzs,
                'status' => PaymentStatus::Paid,
                'paid_at' => now(),
                'recorded_by_user_id' => $online ? null : $assignment->courier_id,
            ]);
        });
    }

    /**
     * Cancelled for a reason. Applied after a state that made a Shopper or a
     * Courier assignment, it ends that assignment with `order_cancelled`.
     */
    public function cancelled(CancellationReason $reason = CancellationReason::CustomerCancelled): self
    {
        return $this->state(fn (): array => [
            'status' => OrderStatus::Cancelled,
            'cancelled_at' => now(),
            'cancellation_reason_code' => $reason,
        ])->afterCreating(function (Order $order): void {
            foreach ([$order->shopperAssignments(), $order->courierAssignments()] as $assignments) {
                $assignments->whereNull('ended_at')->update([
                    'ended_at' => now(),
                    'ended_reason' => AssignmentEndReason::OrderCancelled->value,
                ]);
            }
        });
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

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function customer(array $attributes): User
    {
        return User::query()->findOrFail($attributes['customer_id']);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function address(array $attributes): CustomerAddress
    {
        return CustomerAddress::query()->findOrFail($attributes['source_address_id']);
    }

    private function withShopper(OrderShopperAssignmentFactory $assignment): self
    {
        return $this->afterCreating(function (Order $order) use ($assignment): void {
            $assignment->create(['order_id' => $order->id]);
        });
    }

    private function withCourier(OrderCourierAssignmentFactory $assignment): self
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
