<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use App\Models\CustomerApproval;
use App\Models\Enums\ApprovalResolution;
use App\Models\Enums\ApprovalStatus;
use App\Models\Enums\ApprovalType;
use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\CancellationReason;
use App\Models\Enums\CancellationRequestOrigin;
use App\Models\Enums\CancellationRequestStatus;
use App\Models\Enums\DeliveryFailureReason;
use App\Models\Enums\ItemRemovedReason;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\PaymentMethod;
use App\Models\Enums\PaymentProvider;
use App\Models\Enums\PaymentStatus;
use App\Models\Enums\Role;
use App\Models\Enums\SubstitutionPolicy;
use App\Models\Enums\SubstitutionResolution;
use App\Models\Order;
use App\Models\OrderCancellationRequest;
use App\Models\OrderCourierAssignment;
use App\Models\OrderItem;
use App\Models\OrderItemPriceCorrection;
use App\Models\Payment;
use App\Models\Product;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * The models and factories of the Wave 3 tables: every factory state produces
 * rows the database accepts and leaves the line and the order as the action it
 * stands for does, an order at each step of the wave carries the Courier
 * assignment and the payment its status implies, and the casts hand back the
 * enums and decimal strings the wave relies on.
 */
final class Wave3ModelsAndFactoriesTest extends TestCase
{
    use RefreshDatabase;

    public function test_an_order_carries_the_courier_and_the_payment_its_status_implies(): void
    {
        $assigned = Order::factory()->deliveryAssigned()->create();
        $this->assertNull($assigned->currentCourierAssignment?->accepted_at);
        $this->assertSame(Role::Courier, $assigned->currentCourierAssignment?->courier->role);

        $onTheWay = Order::factory()->onTheWay()->create();
        $started = $onTheWay->currentCourierAssignment;
        $this->assertNotNull($started?->delivery_started_at);
        $this->assertTrue($started->delay_at->greaterThan($started->delivery_started_at));
        $this->assertSame([], $onTheWay->payments()->get()->all());

        $failed = Order::factory()->deliveryFailed()->create();
        $this->assertSame(OrderStatus::ReadyForDelivery, $failed->status);
        $this->assertNull($failed->currentCourierAssignment);
        $this->assertSame(DeliveryFailureReason::NoAnswer, $failed->courierAssignments()->sole()->failed_reason_code);

        $completed = Order::factory()->completed()->create();
        $this->assertNull($completed->currentCourierAssignment);
        $delivery = $completed->courierAssignments()->sole();
        $this->assertSame(AssignmentEndReason::Completed, $delivery->ended_reason);
        $cash = $completed->payments()->sole();
        $this->assertSame(PaymentMethod::Cash, $cash->method);
        $this->assertSame(PaymentStatus::Paid, $cash->status);
        $this->assertSame(120000, $cash->amount_uzs);
        $this->assertSame($delivery->courier_id, $cash->recorded_by_user_id);
        $this->assertSame($delivery->courier_id, $cash->recordedBy?->id);

        $online = Order::factory()->online()->completed()->create()->payments()->sole();
        $this->assertSame(PaymentProvider::Payme, $online->provider);
        $this->assertNull($online->recorded_by_user_id);

        // A cancellation after a Courier assignment ends it, as the action will.
        $cancelled = Order::factory()->deliveryAssigned()->cancelled()->create();
        $this->assertNull($cancelled->currentCourierAssignment);
        $this->assertSame(AssignmentEndReason::OrderCancelled, $cancelled->courierAssignments()->sole()->ended_reason);
    }

    public function test_a_courier_assignment_walks_through_its_steps(): void
    {
        $current = OrderCourierAssignment::factory()->create();
        $this->assertSame(OrderStatus::DeliveryAssigned, $current->order->status);
        $this->assertFalse($current->is_self_order);
        $this->assertSame(Role::Operator, $current->assignedBy->role);

        $this->assertNotNull(OrderCourierAssignment::factory()->accepted()->create()->accepted_at);

        $failed = OrderCourierAssignment::factory()->ended(AssignmentEndReason::DeliveryFailed)->create()->fresh();
        $this->assertNotNull($failed);
        $this->assertSame(DeliveryFailureReason::NoAnswer, $failed->failed_reason_code);
        $this->assertNotNull($failed->delivery_started_at);

        $replaced = OrderCourierAssignment::factory()->ended(AssignmentEndReason::Reassigned)->create();
        $this->assertNull($replaced->accepted_at);
    }

    public function test_a_line_is_priced_under_its_own_markup(): void
    {
        // 16 000 under 12.5 % is 18 000 (DL-37 (8)), and bought as such.
        $line = OrderItem::factory()->purchased()->create(['markup_percent_snapshot' => '12.50'])->fresh();

        $this->assertNotNull($line);
        $this->assertSame(18000, $line->customer_unit_price_uzs_snapshot);
        $this->assertSame(18000, $line->billable_unit_price_uzs);
    }

    public function test_an_approval_is_a_question_on_a_line_awaiting_the_customer(): void
    {
        $price = CustomerApproval::factory()->create()->fresh();
        $this->assertNotNull($price);
        $this->assertSame(ApprovalType::PriceOverTolerance, $price->type);
        $this->assertSame(ApprovalStatus::Pending, $price->status);
        $this->assertSame(OrderItemStatus::AwaitingCustomer, $price->item->status);
        $this->assertSame(OrderStatus::Shopping, $price->order->status);
        $this->assertSame($price->order->currentShopperAssignment?->shopper_id, $price->requestedBy->id);
        $this->assertTrue($price->expires_at->greaterThan($price->attention_at));
        $this->assertSame($price->id, $price->order->approvals()->sole()->id);
        $this->assertSame($price->id, $price->item->approvals()->sole()->id);

        $substitution = CustomerApproval::factory()->substitution()->create();
        $this->assertSame(SubstitutionPolicy::ContactBefore, $substitution->item->substitution_policy_snapshot);
        $this->assertSame($substitution->item->unit_code_snapshot, $substitution->replacement_unit_code_snapshot);
        $this->assertSame($substitution->replacementProduct?->name_ru, $substitution->replacement_name_ru_snapshot);

        $this->assertSame('1.500', CustomerApproval::factory()->reducedQuantity('1.5')->create()->fresh()?->proposed_quantity);
        $this->assertNull(CustomerApproval::factory()->expired()->create()->resolution);
    }

    public function test_a_resolved_approval_leaves_the_line_as_its_action_does(): void
    {
        $price = CustomerApproval::factory()->approved()->create();
        $this->assertSame(ApprovalResolution::Approved, $price->resolution);
        $this->assertSame($price->order->customer_id, $price->resolvedBy?->id);
        $line = $price->item->fresh();
        $this->assertSame(OrderItemStatus::Pending, $line?->status);
        $this->assertSame(23000, $line->approved_unit_price_ceiling_uzs);

        $replacement = CustomerApproval::factory()->substitution()->approved()->create();
        $line = $replacement->item->fresh();
        $this->assertSame($replacement->replacement_product_id, $line?->fulfilled_product_id);
        $this->assertSame(SubstitutionResolution::Approved, $line?->substitution_resolution);
        $this->assertSame(12650, $line->approved_replacement_price_uzs);

        $fewer = CustomerApproval::factory()->reducedQuantity()->approved()->create();
        $this->assertSame('1.000', $fewer->item->fresh()?->approved_quantity_cap);

        $rejected = CustomerApproval::factory()->rejected()->create();
        $this->assertSame(ItemRemovedReason::CustomerRejected, $rejected->item->fresh()?->removed_reason_code);
        // Its only line gone, nothing is left to buy (DL-54 (7)).
        $this->assertSame(CancellationReason::NoItemsPurchased, $rejected->order->fresh()?->cancellation_reason_code);

        $kept = CustomerApproval::factory()->rejected()->create([
            'order_item_id' => fn (): string => OrderItem::factory()->awaitingCustomer()->for(
                Order::factory()->shopping()->has(OrderItem::factory(), 'items')
            )->create()->id,
        ]);
        $this->assertSame(OrderStatus::Shopping, $kept->order->fresh()?->status, 'Another line is still to buy.');

        $aboutTheReplacement = CustomerApproval::factory()->aboutTheReplacement()->approved()->create();
        $line = $aboutTheReplacement->item->fresh();
        $this->assertSame($line?->fulfilled_product_id, $aboutTheReplacement->replacement_product_id);
        $this->assertSame(23000, $line?->approved_replacement_price_uzs);
        $this->assertNull($line->approved_unit_price_ceiling_uzs);

        $removed = CustomerApproval::factory()->removedByAnOperator()->create();
        $this->assertSame(ApprovalResolution::RemoveItem, $removed->resolution);
        $this->assertSame(Role::Operator, $removed->resolvedBy?->role);
        $this->assertSame(ItemRemovedReason::ApprovalExpired, $removed->item->fresh()?->removed_reason_code);

        $cancelled = CustomerApproval::factory()->cancelled()->create();
        $this->assertSame(ApprovalStatus::Cancelled, $cancelled->status);
        $order = $cancelled->order->fresh();
        $this->assertSame(OrderStatus::Cancelled, $order?->status);
        $this->assertNull($order->currentShopperAssignment);
        $this->assertSame(ItemRemovedReason::OrderCancelled, $cancelled->item->fresh()?->removed_reason_code);
        $this->assertSame(CancellationRequestStatus::Approved, $order->cancellationRequests()->sole()->status);
    }

    public function test_a_cancellation_request_is_filed_by_the_customer_and_then_decided_or_closed(): void
    {
        $pending = OrderCancellationRequest::factory()->create();
        $this->assertSame(CancellationRequestOrigin::Customer, $pending->origin);
        $this->assertSame(CancellationRequestStatus::Pending, $pending->status);
        $this->assertSame($pending->order->customer_id, $pending->requestedBy->id);
        $this->assertSame($pending->id, $pending->order->cancellationRequests()->sole()->id);

        $approved = OrderCancellationRequest::factory()->approved()->create();
        $this->assertSame(Role::Operator, $approved->resolvedBy?->role);
        $this->assertSame(CancellationReason::CancellationRequestApproved, $approved->order->fresh()?->cancellation_reason_code);
        $this->assertNull($approved->order->fresh()->currentShopperAssignment);

        $rejected = OrderCancellationRequest::factory()->rejected()->create();
        $this->assertSame(OrderStatus::Shopping, $rejected->order->fresh()?->status);

        $closed = OrderCancellationRequest::factory()->closed()->create();
        $this->assertNull($closed->resolved_by_user_id);
        $this->assertSame(CancellationReason::NoItemsPurchased, $closed->order->fresh()?->cancellation_reason_code);
    }

    public function test_a_price_correction_and_a_payment_sit_where_their_actions_leave_them(): void
    {
        $correction = OrderItemPriceCorrection::factory()->create()->fresh();
        $this->assertNotNull($correction);
        $this->assertSame(Role::Admin, $correction->correctedBy->role);
        $this->assertSame($correction->id, $correction->item->priceCorrections()->sole()->id);
        $this->assertSame($correction->new_actual_market_price_uzs, $correction->item->actual_market_price_uzs);
        $this->assertSame($correction->new_billable_unit_price_uzs, $correction->item->billable_unit_price_uzs);
        $this->assertSame(OrderStatus::ReadyForDelivery, $correction->item->order->status);

        $payment = Payment::factory()->create();
        $this->assertSame(OrderStatus::Completed, $payment->order->status);
        $this->assertSame($payment->order->courierAssignments()->sole()->courier_id, $payment->recorded_by_user_id);
        $this->assertSame($payment->order->final_total_uzs, $payment->amount_uzs);
        $this->assertSame($payment->id, $payment->order->payments()->sole()->id);

        // The replacement a factory proposes is a product of the line's unit.
        $this->assertInstanceOf(Product::class, CustomerApproval::factory()->substitution()->create()->replacementProduct);
    }
}
