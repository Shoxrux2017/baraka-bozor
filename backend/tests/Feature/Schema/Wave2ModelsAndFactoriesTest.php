<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use App\Models\CartItem;
use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\CancellationReason;
use App\Models\Enums\CartStatus;
use App\Models\Enums\ItemRemovedReason;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\PaymentMethod;
use App\Models\Enums\PriceMode;
use App\Models\Enums\Role;
use App\Models\Enums\ServiceFeeMode;
use App\Models\Enums\SubstitutionPolicy;
use App\Models\Enums\UnitCode;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * The models and factories of the Wave 2 tables: every factory state produces
 * a row the database accepts — an order in each of its nine states among them —
 * and the casts hand back the enums and decimal strings the wave relies on.
 */
final class Wave2ModelsAndFactoriesTest extends TestCase
{
    use RefreshDatabase;

    public function test_a_cart_line_belongs_to_a_customers_active_cart(): void
    {
        $line = CartItem::factory()->create(['quantity' => '2.5']);

        $this->assertSame(CartStatus::Active, $line->cart->status);
        $this->assertSame(Role::Customer, $line->cart->customer->role);
        $this->assertSame('2.500', $line->quantity);
        $this->assertSame(SubstitutionPolicy::AllowSimilar, $line->substitution_policy);
        $this->assertSame($line->id, $line->cart->items()->sole()->id);
    }

    public function test_a_new_order_is_placed_from_the_customers_own_cart_and_address(): void
    {
        $order = Order::factory()->create();

        $this->assertSame(OrderStatus::New, $order->status);
        $this->assertSame(PaymentMethod::Cash, $order->payment_method);
        $this->assertGreaterThanOrEqual(1001, $order->fresh()?->order_number);
        $this->assertSame($order->customer_id, $order->sourceCart->customer_id);
        $this->assertSame(CartStatus::Converted, $order->sourceCart->status);
        $this->assertSame($order->customer_id, $order->sourceAddress->customer_id);
        $this->assertSame($order->customer->phone, $order->recipient_phone_snapshot);
        $this->assertSame('15.00', $order->markup_percent_snapshot);
        $this->assertSame(ServiceFeeMode::Fixed, $order->service_fee_mode_snapshot);
        $this->assertNull($order->currentShopperAssignment);
    }

    public function test_every_status_has_a_state_the_database_accepts(): void
    {
        $cases = [
            'new' => [Order::factory(), OrderStatus::New, false],
            'shopping_assigned' => [Order::factory()->shoppingAssigned(), OrderStatus::ShoppingAssigned, true],
            'shopping' => [Order::factory()->shopping(), OrderStatus::Shopping, true],
            'final_payment_pending' => [Order::factory()->finalPaymentPending(), OrderStatus::FinalPaymentPending, false],
            'ready_for_delivery' => [Order::factory()->readyForDelivery(), OrderStatus::ReadyForDelivery, false],
            'delivery_assigned' => [Order::factory()->deliveryAssigned(), OrderStatus::DeliveryAssigned, false],
            'on_the_way' => [Order::factory()->onTheWay(), OrderStatus::OnTheWay, false],
            'completed' => [Order::factory()->completed(), OrderStatus::Completed, false],
            'cancelled' => [Order::factory()->cancelled(CancellationReason::System), OrderStatus::Cancelled, false],
        ];

        foreach ($cases as $name => [$factory, $status, $currentShopper]) {
            $order = $factory->create()->fresh();
            $this->assertNotNull($order, $name);
            $this->assertSame($status, $order->status, $name);
            $this->assertSame($currentShopper, $order->currentShopperAssignment !== null, "{$name}: the current Shopper");
        }

        $shopping = Order::factory()->shopping()->create();
        $this->assertNotNull($shopping->currentShopperAssignment?->started_at);

        $completed = Order::factory()->completed()->create();
        $ended = $completed->shopperAssignments()->sole();
        $this->assertSame(AssignmentEndReason::Completed, $ended->ended_reason);
        $this->assertSame(120000, $completed->final_total_uzs);
        $this->assertSame(PaymentMethod::Online, Order::factory()->finalPaymentPending()->create()->payment_method);
    }

    public function test_a_line_snapshots_its_product_and_the_states_hold(): void
    {
        $product = Product::factory()->fixed()->unit(UnitCode::Piece)->create(['market_price_uzs' => 3000]);
        $order = Order::factory()->create();

        $pending = OrderItem::factory()->for($order)->for($product)->create();
        $this->assertSame(OrderItemStatus::Pending, $pending->status);
        $this->assertSame(PriceMode::Fixed, $pending->price_mode_snapshot);
        $this->assertSame(UnitCode::Piece, $pending->unit_code_snapshot);
        $this->assertSame(3450, $pending->customer_unit_price_uzs_snapshot);
        $this->assertSame('15.00', $pending->markup_percent_snapshot);
        $this->assertSame('0.000', $pending->billable_quantity);

        $bought = OrderItem::factory()->for($order)->for($product)->purchased()->create(['ordered_quantity' => '3']);
        $this->assertSame(OrderItemStatus::Purchased, $bought->status);
        $this->assertSame('3.000', $bought->fresh()?->billable_quantity);
        $this->assertSame(10350, $bought->line_total_uzs);
        $this->assertSame($product->id, $bought->fulfilled_product_id);

        $removed = OrderItem::factory()->for($order)->removed(ItemRemovedReason::OrderCancelled)->create();
        $this->assertSame(ItemRemovedReason::OrderCancelled, $removed->removed_reason_code);
        $this->assertSame(0, $removed->line_total_uzs);

        $this->assertSame(3, $order->items()->count());
    }
}
