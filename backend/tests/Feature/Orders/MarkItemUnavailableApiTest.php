<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\CancellationReason;
use App\Models\Enums\CancellationRequestStatus;
use App\Models\Enums\ItemRemovedReason;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\Role;
use App\Models\Enums\SubstitutionPolicy;
use App\Models\Enums\SubstitutionResolution;
use App\Models\Order;
use App\Models\OrderCancellationRequest;
use App\Models\OrderHistory;
use App\Models\OrderItem;
use App\Models\OrderShopperAssignment;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * A line the Shopper could not find: `docs/09` section 31, `docs/04`
 * section 17, `DL-54` (7), (9), (23) and `DL-57`.
 */
final class MarkItemUnavailableApiTest extends TestCase
{
    use RefreshDatabase;

    private User $shopper;

    private Order $order;

    protected function setUp(): void
    {
        parent::setUp();

        $this->shopper = User::factory()->role(Role::Shopper)->create();
        $this->order = Order::factory()->shopping()->create();
        $this->order->shopperAssignments()->update(['shopper_id' => $this->shopper->id]);
    }

    public function test_a_line_is_removed_whatever_its_rule_and_the_note_is_kept(): void
    {
        $kept = OrderItem::factory()->for($this->order)->create();

        foreach (SubstitutionPolicy::cases() as $rule) {
            $line = OrderItem::factory()->for($this->order)->create(['substitution_policy_snapshot' => $rule]);

            $data = $this->unavailable($line, ['note' => 'Нет на рынке'])->assertOk()->json('data');

            $this->assertSame('shopping', $data['status']);
            $gone = $line->fresh();
            $this->assertSame(OrderItemStatus::Removed, $gone?->status);
            $this->assertSame(ItemRemovedReason::Unavailable, $gone->removed_reason_code);
            $this->assertSame(0, $gone->line_total_uzs);
        }

        $rows = OrderHistory::query()->where('order_id', $this->order->id)->get();
        $this->assertCount(3, $rows);
        $this->assertSame([OrderHistoryEvent::ItemUnavailable], $rows->pluck('event_type')->unique()->values()->all());
        $this->assertSame('Нет на рынке', $rows->first()?->note);
        $this->assertNull($rows->first()->to_status);
        $this->assertSame(OrderItemStatus::Pending, $kept->fresh()?->status);
    }

    public function test_the_last_line_leaves_nothing_to_buy_and_cancels_the_order(): void
    {
        $line = OrderItem::factory()->for($this->order)->create();
        OrderItem::factory()->for($this->order)->removed(ItemRemovedReason::CustomerRemoved)->create();
        $request = OrderCancellationRequest::factory()->create(['order_id' => $this->order->id]);

        $data = $this->unavailable($line)->assertOk()->json('data');

        $this->assertSame('cancelled', $data['status']);
        $this->assertNull($data['assignment'], 'The Shopper\'s assignment ended with the order.');
        $order = $this->order->fresh();
        $this->assertSame(OrderStatus::Cancelled, $order?->status);
        $this->assertSame(CancellationReason::NoItemsPurchased, $order->cancellation_reason_code);
        $this->assertSame(AssignmentEndReason::OrderCancelled, $order->shopperAssignments()->sole()->ended_reason);
        $this->assertSame(CancellationRequestStatus::Closed, $request->fresh()?->status);

        // One row carries the move and what it closed (DL-54 (23)).
        $row = OrderHistory::query()->where('order_id', $this->order->id)->sole();
        $this->assertSame(OrderHistoryEvent::ItemUnavailable, $row->event_type);
        $this->assertSame(OrderStatus::Shopping, $row->from_status);
        $this->assertSame(OrderStatus::Cancelled, $row->to_status);
        $this->assertSame(CancellationReason::NoItemsPurchased, $row->reason_code);
        $this->assertSame(['item_id' => $line->id, 'closed_cancellation_request_id' => $request->id], $row->details);

        // The Customer owes nothing (BR-CAN-006).
        $this->withToken($this->order->customer->createToken('c')->plainTextToken)
            ->getJson("/api/v1/customer/orders/{$this->order->id}")
            ->assertOk()
            ->assertJsonPath('data.totals.total_kind', 'none');
        // And the order has left the Shopper's hands.
        $this->as($this->shopper)->getJson("/api/v1/shopper/orders/{$this->order->id}")->assertStatus(404);
    }

    public function test_a_bought_line_keeps_the_order_going(): void
    {
        OrderItem::factory()->for($this->order)->purchased()->create();
        $line = OrderItem::factory()->for($this->order)->create();

        $this->unavailable($line)->assertOk()->assertJsonPath('data.status', 'shopping');
    }

    public function test_a_repeat_meets_the_line_resolved_and_a_body_is_held_to_its_form(): void
    {
        $line = OrderItem::factory()->for($this->order)->create();
        OrderItem::factory()->for($this->order)->create();

        $this->unavailable($line, ['reason' => 'gone'])->assertStatus(422);
        $this->unavailable($line, ['note' => str_repeat('a', 301)])->assertStatus(422)->assertJsonStructure(['errors' => ['note']]);

        $this->unavailable($line)->assertOk();
        $this->unavailable($line)->assertStatus(409)->assertJsonPath('code', 'item_already_resolved');
        $this->assertSame(1, OrderHistory::query()->where('order_id', $this->order->id)->count());
    }

    public function test_only_a_pending_line_of_an_order_being_shopped_by_the_caller_is_marked(): void
    {
        $removed = OrderItem::factory()->for($this->order)->removed(ItemRemovedReason::CustomerRemoved)->create();
        $this->unavailable($removed)->assertStatus(404);

        $notStarted = Order::factory()->state(['status' => OrderStatus::ShoppingAssigned])->create();
        OrderShopperAssignment::factory()->accepted()->create(['order_id' => $notStarted->id, 'shopper_id' => $this->shopper->id]);
        $this->unavailable(OrderItem::factory()->for($notStarted)->create())
            ->assertStatus(409)->assertJsonPath('code', 'shopping_not_active');

        $line = OrderItem::factory()->for($this->order)->create();
        $this->as(User::factory()->role(Role::Shopper)->create())
            ->postJson("/api/v1/shopper/orders/{$line->order_id}/items/{$line->id}/unavailable")
            ->assertStatus(404);

        $this->assertSame(OrderItemStatus::Pending, $line->fresh()?->status);
        $this->assertSame(0, OrderHistory::query()->count());
    }

    public function test_a_removed_line_shows_no_replacement(): void
    {
        OrderItem::factory()->for($this->order)->create();
        $replacement = Product::factory()->create();
        $line = OrderItem::factory()->for($this->order)->create();
        $line->forceFill([
            'fulfilled_product_id' => $replacement->id,
            'fulfilled_product_name_uz_snapshot' => $replacement->name_uz,
            'fulfilled_product_name_ru_snapshot' => $replacement->name_ru,
            'fulfilled_unit_code_snapshot' => $line->unit_code_snapshot,
            'substitution_resolution' => SubstitutionResolution::Automatic,
        ])->save();

        $shopper = collect($this->unavailable($line)->assertOk()->json('data.items'))->firstWhere('id', $line->id);
        $this->assertNull($shopper['replacement'], 'DL-57 (6): nothing will be bought for a removed line.');

        $customer = collect($this->withToken($this->order->customer->createToken('c')->plainTextToken)
            ->getJson("/api/v1/customer/orders/{$this->order->id}")->assertOk()->json('data.items'))->firstWhere('id', $line->id);
        $this->assertNull($customer['replacement']);

        $board = collect($this->as(User::factory()->role(Role::Operator)->create())
            ->getJson("/api/v1/operations/orders/{$this->order->id}")->assertOk()->json('data.items'))->firstWhere('id', $line->id);
        $this->assertNull($board['replacement']);
    }

    /**
     * @param  array<string, mixed>  $body
     */
    private function unavailable(OrderItem $line, array $body = []): TestResponse
    {
        return $this->as($this->shopper)->postJson("/api/v1/shopper/orders/{$line->order_id}/items/{$line->id}/unavailable", $body);
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
