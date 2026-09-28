<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use App\Models\CustomerApproval;
use App\Models\Enums\ApprovalResolution;
use App\Models\Enums\ApprovalStatus;
use App\Models\Enums\ApprovalType;
use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\CancellationRequestOrigin;
use App\Models\Enums\CancellationRequestStatus;
use App\Models\Enums\DeliveryFailureReason;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\PaymentMethod;
use App\Models\Enums\PaymentProvider;
use App\Models\Enums\PaymentStatus;
use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\OrderCancellationRequest;
use App\Models\OrderCourierAssignment;
use App\Models\OrderItemPriceCorrection;
use App\Models\Payment;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * The models and factories of the Wave 3 tables: every factory state produces
 * rows the database accepts, an order at each step of the wave carries the
 * Courier assignment and the payment its status implies, and the casts hand
 * back the enums and decimal strings the wave relies on.
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

        $completed = Order::factory()->completed()->create();
        $this->assertNull($completed->currentCourierAssignment);
        $delivery = $completed->courierAssignments()->sole();
        $this->assertSame(AssignmentEndReason::Completed, $delivery->ended_reason);
        $cash = $completed->payments()->sole();
        $this->assertSame(PaymentMethod::Cash, $cash->method);
        $this->assertSame(PaymentStatus::Paid, $cash->status);
        $this->assertSame(120000, $cash->amount_uzs);
        $this->assertSame($delivery->courier_id, $cash->recorded_by_user_id);
        $this->assertSame($delivery->courier_id, $cash->recordedBy->id);

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
        $this->assertSame(DeliveryFailureReason::NoAnswer, $failed?->failed_reason_code);
        $this->assertNotNull($failed->delivery_started_at);

        $replaced = OrderCourierAssignment::factory()->ended(AssignmentEndReason::Reassigned)->create();
        $this->assertNull($replaced->accepted_at);
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
        $this->assertSame($substitution->replacementProduct?->name_ru, $substitution->replacement_name_ru_snapshot);
        $this->assertSame($substitution->replacementProduct?->unit_code, $substitution->replacement_unit_code_snapshot);

        $this->assertSame('1.500', CustomerApproval::factory()->reducedQuantity('1.5')->create()->fresh()?->proposed_quantity);

        $approved = CustomerApproval::factory()->approved()->create();
        $this->assertSame(ApprovalResolution::Approved, $approved->resolution);
        $this->assertSame($approved->order->customer_id, $approved->resolvedBy?->id);
        $this->assertSame(ApprovalResolution::Rejected, CustomerApproval::factory()->rejected()->create()->resolution);

        $this->assertNull(CustomerApproval::factory()->expired()->create()->resolution);
        $removed = CustomerApproval::factory()->removedByAnOperator()->create();
        $this->assertSame(ApprovalResolution::RemoveItem, $removed->resolution);
        $this->assertSame(Role::Operator, $removed->resolvedBy?->role);

        $this->assertSame(ApprovalStatus::Cancelled, CustomerApproval::factory()->cancelled()->create()->status);
    }

    public function test_a_cancellation_request_is_filed_by_the_customer_and_then_decided_or_closed(): void
    {
        $pending = OrderCancellationRequest::factory()->create();
        $this->assertSame(CancellationRequestOrigin::Customer, $pending->origin);
        $this->assertSame(CancellationRequestStatus::Pending, $pending->status);
        $this->assertSame($pending->order->customer_id, $pending->requestedBy->id);
        $this->assertSame($pending->id, $pending->order->cancellationRequests()->sole()->id);

        $this->assertSame(Role::Operator, OrderCancellationRequest::factory()->approved()->create()->resolvedBy?->role);
        $this->assertSame(CancellationRequestStatus::Rejected, OrderCancellationRequest::factory()->rejected()->create()->status);

        $closed = OrderCancellationRequest::factory()->closed()->create();
        $this->assertNull($closed->resolved_by_user_id);
        $this->assertNotNull($closed->resolved_at);
    }

    public function test_a_price_correction_and_a_payment_stand_on_their_own(): void
    {
        $correction = OrderItemPriceCorrection::factory()->create()->fresh();
        $this->assertNotNull($correction);
        $this->assertSame(15000, $correction->new_actual_market_price_uzs);
        $this->assertSame(Role::Admin, $correction->correctedBy->role);
        $this->assertSame($correction->id, $correction->item->priceCorrections()->sole()->id);

        $payment = Payment::factory()->create();
        $this->assertSame(OrderStatus::OnTheWay, $payment->order->status);
        $this->assertSame($payment->order->currentCourierAssignment?->courier_id, $payment->recorded_by_user_id);
        $this->assertSame($payment->order->final_total_uzs, $payment->amount_uzs);
    }
}
