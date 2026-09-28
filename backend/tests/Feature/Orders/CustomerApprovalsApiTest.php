<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\CustomerApproval;
use App\Models\Enums\ApprovalResolution;
use App\Models\Enums\ApprovalStatus;
use App\Models\Enums\ApprovalType;
use App\Models\Enums\CancellationReason;
use App\Models\Enums\CancellationRequestStatus;
use App\Models\Enums\ItemRemovedReason;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\Role;
use App\Models\Enums\SubstitutionResolution;
use App\Models\Order;
use App\Models\OrderCancellationRequest;
use App\Models\OrderHistory;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * The Customer's questions and decisions: `docs/09` sections 20 and 23,
 * `BR-APP-001` to `BR-APP-011`, `DL-54` (5), (7), (8) and `DL-59`.
 */
final class CustomerApprovalsApiTest extends TestCase
{
    use RefreshDatabase;

    private Order $order;

    private User $customer;

    protected function setUp(): void
    {
        parent::setUp();

        $this->order = Order::factory()->shopping()->create();
        $this->customer = $this->order->customer;
    }

    public function test_the_customer_lists_and_reads_their_own_questions_without_the_market_price(): void
    {
        $older = $this->question(['created_at' => now()->subMinutes(5)]);
        $newer = $this->question(['request_note' => 'Подорожали']);
        CustomerApproval::factory()->create();

        $list = $this->as($this->customer)->getJson('/api/v1/customer/approvals')->assertOk();
        $this->assertSame([$newer->id, $older->id], array_column($list->json('data'), 'id'));

        $data = $this->as($this->customer)->getJson("/api/v1/customer/approvals/{$newer->id}")->assertOk()->json('data');
        $this->assertSame([
            'id' => $newer->id,
            'order_id' => $this->order->id,
            'order_number' => $this->order->fresh()?->order_number,
            'type' => 'price_over_tolerance',
            'status' => 'pending',
            'item' => [
                'id' => $newer->order_item_id,
                'name_uz' => $newer->item->product_name_uz_snapshot,
                'name_ru' => $newer->item->product_name_ru_snapshot,
                'unit_code' => 'kg',
                'price_mode' => 'estimate',
                'quantity' => '2.000',
                'customer_unit_price_uzs' => 18400,
            ],
            'proposed_customer_unit_price_uzs' => 23000,
            'proposed_quantity' => null,
            'replacement' => null,
            'request_note' => 'Подорожали',
            'expires_at' => $newer->expires_at->toIso8601ZuluString(),
            'resolved_at' => null,
            'created_at' => $newer->created_at->toIso8601ZuluString(),
        ], $data);
        $this->assertStringNotContainsString('20000', json_encode($data, JSON_THROW_ON_ERROR), 'BR-PRICE-001: never the price paid.');

        $foreign = CustomerApproval::factory()->create();
        $this->as($this->customer)->getJson("/api/v1/customer/approvals/{$foreign->id}")->assertStatus(404);
        $this->as($this->customer)->getJson('/api/v1/customer/approvals/'.Str::uuid())->assertStatus(404);
        $this->as(User::factory()->role(Role::Shopper)->create())->getJson('/api/v1/customer/approvals')->assertStatus(403);
    }

    public function test_pending_leaves_out_a_question_past_its_expiry_which_reads_as_expired(): void
    {
        $open = $this->question();
        $overdue = $this->question(['attention_at' => now()->subMinutes(25), 'expires_at' => now()->subMinute()]);

        $pending = $this->as($this->customer)->getJson('/api/v1/customer/approvals?status=pending')->assertOk();
        $this->assertSame([$open->id], array_column($pending->json('data'), 'id'));

        $expired = $this->as($this->customer)->getJson('/api/v1/customer/approvals?status=expired')->assertOk();
        $this->assertSame([$overdue->id], array_column($expired->json('data'), 'id'));
        $this->assertSame('expired', $expired->json('data.0.status'));

        $this->as($this->customer)->getJson('/api/v1/customer/approvals?status=waiting')->assertStatus(422);

        $order = $this->as($this->customer)->getJson("/api/v1/customer/orders/{$this->order->id}")->assertOk();
        $this->assertSame(1, $order->json('data.pending_approval_count'));
        $this->assertSame(1, $this->as($this->customer)->getJson('/api/v1/customer/orders')->json('data.0.pending_approval_count'));
    }

    public function test_at_its_expiry_instant_a_question_reads_as_expired_everywhere(): void
    {
        Carbon::setTestNow(CarbonImmutable::parse('2026-09-28T10:30:00Z'));
        $due = $this->question(['attention_at' => now()->subMinutes(20), 'expires_at' => now()]);

        $this->assertSame([], $this->as($this->customer)->getJson('/api/v1/customer/approvals?status=pending')->json('data'));
        $this->assertSame([$due->id], array_column($this->as($this->customer)->getJson('/api/v1/customer/approvals?status=expired')->json('data'), 'id'));
        $this->assertSame('expired', $this->as($this->customer)->getJson("/api/v1/customer/approvals/{$due->id}")->json('data.status'));
        $this->assertSame(0, $this->as($this->customer)->getJson("/api/v1/customer/orders/{$this->order->id}")->json('data.pending_approval_count'));
        $this->assertSame(0, $this->as($this->customer)->getJson('/api/v1/customer/orders')->json('data.0.pending_approval_count'));
        Carbon::setTestNow();
    }

    public function test_what_the_customer_approved_is_what_the_shopper_may_buy(): void
    {
        $approval = $this->question();
        $this->decide($approval, 'approve')->assertOk();

        $shopper = $this->withToken($this->order->currentShopperAssignment?->shopper->createToken('s')->plainTextToken ?? '');
        $url = "/api/v1/shopper/orders/{$this->order->id}/items/{$approval->order_item_id}/purchase";
        // 20 001 × 1.15 = 23 001: one UZS above the 23 000 approved.
        $shopper->withHeader('Idempotency-Key', (string) Str::uuid())
            ->postJson($url, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 20001])
            ->assertStatus(409)->assertJsonPath('details.ceiling_customer_unit_price_uzs', 23000);
        $shopper->withHeader('Idempotency-Key', (string) Str::uuid())
            ->postJson($url, ['purchased_quantity' => '2.000', 'actual_market_price_uzs' => 20000])
            ->assertOk();
        $this->assertSame(23000, $approval->item->fresh()->billable_unit_price_uzs);
    }

    public function test_a_decision_is_held_to_the_locked_state_of_the_order_and_the_line(): void
    {
        $onACancelledOrder = $this->question();
        $this->order->forceFill(['status' => OrderStatus::Cancelled, 'cancelled_at' => now(), 'cancellation_reason_code' => CancellationReason::System])->save();
        $this->decide($onACancelledOrder, 'approve')->assertStatus(409)->assertJsonPath('code', 'order_state_conflict');

        $this->order = Order::factory()->shopping()->create();
        $this->customer = $this->order->customer;
        $notWaiting = $this->question();
        $notWaiting->item->forceFill(['status' => OrderItemStatus::Pending])->save();
        $this->decide($notWaiting, 'approve')->assertStatus(409)->assertJsonPath('code', 'order_state_conflict');

        $aboutAnother = CustomerApproval::factory()->aboutTheReplacement()->create();
        $other = Product::factory()->create();
        $aboutAnother->item->forceFill([
            'fulfilled_product_id' => $other->id,
            'fulfilled_product_name_uz_snapshot' => $other->name_uz,
            'fulfilled_product_name_ru_snapshot' => $other->name_ru,
        ])->save();
        $this->decide($aboutAnother, 'approve', $aboutAnother->order->customer)
            ->assertStatus(409)->assertJsonPath('code', 'order_state_conflict');
        $this->assertNull($aboutAnother->item->fresh()?->approved_replacement_price_uzs);

        $this->assertSame(0, DB::table('idempotency_keys')->count(), 'A refusal frees its key.');
    }

    public function test_approving_a_price_raises_the_ceiling_of_what_it_asked_about(): void
    {
        // About the original: its ceiling rises, and a replacement authorized
        // on the line is dropped, as buying the original drops it (DL-59 (3)).
        $replacement = Product::factory()->create();
        $original = $this->question();
        $original->item->forceFill([
            'fulfilled_product_id' => $replacement->id,
            'fulfilled_product_name_uz_snapshot' => $replacement->name_uz,
            'fulfilled_product_name_ru_snapshot' => $replacement->name_ru,
            'fulfilled_unit_code_snapshot' => $original->item->unit_code_snapshot,
            'substitution_resolution' => SubstitutionResolution::Automatic,
        ])->save();

        $data = $this->decide($original, 'approve')->assertOk()->json('data');

        $this->assertSame('approved', $data['status']);
        $line = $original->item->fresh();
        $this->assertSame(OrderItemStatus::Pending, $line?->status);
        $this->assertSame(23000, $line->approved_unit_price_ceiling_uzs);
        $this->assertNull($line->fulfilled_product_id);
        $this->assertNull($line->substitution_resolution);
        $approval = $original->fresh();
        $this->assertSame(ApprovalResolution::Approved, $approval?->resolution);
        $this->assertSame($this->customer->id, $approval->resolved_by_user_id);

        $row = OrderHistory::query()->where('event_type', OrderHistoryEvent::ApprovalDecided)->sole();
        $this->assertEquals(['approval_id' => $original->id, 'item_id' => $line->id, 'decision' => 'approve'], $row->details);
        $this->assertSame($this->customer->id, $row->actor_user_id);

        // About the authorized replacement: its approved price is set.
        $asked = CustomerApproval::factory()->aboutTheReplacement()->create();
        $this->decide($asked, 'approve', $asked->order->customer)->assertOk();
        $this->assertSame(23000, $asked->item->fresh()?->approved_replacement_price_uzs);
    }

    public function test_approving_a_replacement_or_a_smaller_quantity_writes_it_onto_the_line(): void
    {
        $substitution = $this->question(state: 'substitution');
        $this->decide($substitution, 'approve')->assertOk();
        $line = $substitution->item->fresh();
        $this->assertSame($substitution->replacement_product_id, $line?->fulfilled_product_id);
        $this->assertSame(SubstitutionResolution::Approved, $line?->substitution_resolution);
        $this->assertSame(12650, $line->approved_replacement_price_uzs);
        $this->assertSame(OrderItemStatus::Pending, $line->status);

        $fewer = $this->question(state: 'reducedQuantity');
        $this->decide($fewer, 'approve')->assertOk();
        $this->assertSame('1.000', $fewer->item->fresh()?->approved_quantity_cap);
        $this->assertSame(OrderItemStatus::Pending, $fewer->item->fresh()->status);
    }

    public function test_rejecting_removes_the_line_and_the_last_line_cancels_the_order(): void
    {
        $kept = $this->question();
        $rejected = $this->question();

        $this->decide($rejected, 'reject')->assertOk()->assertJsonPath('data.status', 'rejected');
        $this->assertSame(ItemRemovedReason::CustomerRejected, $rejected->item->fresh()?->removed_reason_code);
        $this->assertSame(OrderStatus::Shopping, $this->order->fresh()?->status);

        $request = OrderCancellationRequest::factory()->create(['order_id' => $this->order->id]);
        $key = (string) Str::uuid();
        $this->decide($kept, 'reject', key: $key)->assertOk();
        // A replay after the order was cancelled answers the approval.
        $this->decide($kept, 'reject', key: $key)->assertOk()->assertJsonPath('data.status', 'rejected');
        $this->assertSame(2, OrderHistory::query()->where('order_id', $this->order->id)->count(), 'One row per decision (DL-54 (23)).');

        $order = $this->order->fresh();
        $this->assertSame(OrderStatus::Cancelled, $order->status);
        $this->assertSame(CancellationReason::NoItemsPurchased, $order->cancellation_reason_code);
        $this->assertSame(CancellationRequestStatus::Closed, $request->fresh()?->status);
        $last = OrderHistory::query()->where('event_type', OrderHistoryEvent::ApprovalDecided)->latest('created_at')->latest('id')->first();
        $this->assertSame(OrderStatus::Cancelled, $last?->to_status);
        $this->assertSame(CancellationReason::NoItemsPurchased, $last->reason_code);
        $this->as($this->customer)->getJson("/api/v1/customer/orders/{$this->order->id}")
            ->assertJsonPath('data.totals.total_kind', 'none');
    }

    public function test_an_approval_is_answered_before_its_thirty_minutes_and_expiry_is_never_consent(): void
    {
        Carbon::setTestNow(CarbonImmutable::parse('2026-09-28T10:00:00Z'));
        $inTime = $this->question(['attention_at' => now()->addMinutes(10), 'expires_at' => now()->addMinutes(30)]);
        $late = $this->question(['attention_at' => now()->addMinutes(10), 'expires_at' => now()->addMinutes(30)]);

        Carbon::setTestNow(CarbonImmutable::parse('2026-09-28T10:29:59Z'));
        $this->decide($inTime, 'approve')->assertOk();

        Carbon::setTestNow(CarbonImmutable::parse('2026-09-28T10:30:00Z'));
        $this->decide($late, 'approve')->assertStatus(409)->assertJsonPath('code', 'approval_expired');

        // The expiry stands although the decision was refused (DL-54 (8)).
        $this->assertSame(ApprovalStatus::Expired, $late->fresh()?->status);
        $this->assertNull($late->fresh()->resolution, 'BR-APP-004: expiry is not consent.');
        $this->assertSame(OrderItemStatus::AwaitingCustomer, $late->item->fresh()?->status);
        $expiry = OrderHistory::query()->where('event_type', OrderHistoryEvent::ApprovalExpired)->sole();
        $this->assertNull($expiry->actor_user_id);
        Carbon::setTestNow();
    }

    public function test_a_decision_is_idempotent_and_final(): void
    {
        $approval = $this->question();
        $key = (string) Str::uuid();

        $this->decide($approval, 'approve', key: $key)->assertOk();
        $this->decide($approval, 'approve', key: $key)->assertOk()->assertJsonPath('data.status', 'approved');
        $this->decide($approval, 'reject', key: $key)->assertStatus(409)->assertJsonPath('code', 'idempotency_key_reused');
        $this->decide($approval, 'reject')->assertStatus(409)->assertJsonPath('code', 'approval_already_resolved');
        $this->assertSame(1, OrderHistory::query()->where('event_type', OrderHistoryEvent::ApprovalDecided)->count());

        $other = $this->question();
        $this->decide($other, 'maybe')->assertStatus(422)->assertJsonStructure(['errors' => ['decision']]);
        $this->decide($other, 'approve', null, null, ['decision' => 'approve', 'note' => 'x'])->assertStatus(422);
        $this->flushHeaders();
        $this->as($this->customer)->postJson("/api/v1/customer/approvals/{$other->id}/decision", ['decision' => 'approve'])
            ->assertStatus(400)->assertJsonPath('code', 'idempotency_key_required');

        $foreign = CustomerApproval::factory()->create();
        $this->decide($foreign, 'approve')->assertStatus(404);
        $this->decide($other, 'approve', User::factory()->role(Role::Shopper)->create())->assertStatus(403);

        $cancelled = CustomerApproval::factory()->cancelled()->create();
        $this->decide($cancelled, 'approve', $cancelled->order->customer)->assertStatus(409)->assertJsonPath('code', 'approval_already_resolved');
        $expired = CustomerApproval::factory()->expired()->create();
        $this->decide($expired, 'approve', $expired->order->customer)->assertStatus(409)->assertJsonPath('code', 'approval_expired');
        $this->assertSame(0, OrderHistory::query()->where('event_type', OrderHistoryEvent::ApprovalExpired)->count(), 'An expiry already written is not written again.');

        $this->assertSame(1, DB::table('idempotency_keys')->count(), 'Only the successful decision keeps its key.');
    }

    public function test_a_line_waiting_on_an_expired_substitution_shows_no_earlier_replacement(): void
    {
        $substitution = $this->question(['attention_at' => now()->subMinutes(25), 'expires_at' => now()->subMinute()], 'substitution');
        $substitution->item->forceFill([
            'fulfilled_product_id' => Product::factory()->create()->id,
            'fulfilled_product_name_uz_snapshot' => 'Eski',
            'fulfilled_product_name_ru_snapshot' => 'Старая',
            'fulfilled_unit_code_snapshot' => $substitution->item->unit_code_snapshot,
            'substitution_resolution' => SubstitutionResolution::Automatic,
        ])->save();

        $line = collect($this->as($this->customer)->getJson("/api/v1/customer/orders/{$this->order->id}")->json('data.items'))
            ->firstWhere('id', $substitution->order_item_id);

        $this->assertNull($line['pending_approval']);
        $this->assertNull($line['replacement'], 'DL-59 (2): no one will buy the earlier replacement.');
        $this->assertSame(ApprovalType::Substitution, $substitution->type);
    }

    public function test_the_order_shows_the_open_question_on_its_line(): void
    {
        $substitution = $this->question(state: 'substitution');
        $substitution->item->forceFill([
            'fulfilled_product_id' => Product::factory()->create()->id,
            'fulfilled_product_name_uz_snapshot' => 'Eski',
            'fulfilled_product_name_ru_snapshot' => 'Старая',
            'fulfilled_unit_code_snapshot' => $substitution->item->unit_code_snapshot,
            'substitution_resolution' => SubstitutionResolution::Automatic,
        ])->save();

        $line = collect($this->as($this->customer)->getJson("/api/v1/customer/orders/{$this->order->id}")->assertOk()->json('data.items'))
            ->firstWhere('id', $substitution->order_item_id);

        $this->assertNull($line['replacement'], 'DL-58 (3): the earlier replacement is not the one asked about.');
        $this->assertSame([
            'id' => $substitution->id,
            'type' => 'substitution',
            'proposed_customer_unit_price_uzs' => 12650,
            'proposed_quantity' => null,
            'replacement' => [
                'name_uz' => $substitution->replacement_name_uz_snapshot,
                'name_ru' => $substitution->replacement_name_ru_snapshot,
                'customer_unit_price_uzs' => 12650,
            ],
            'request_note' => null,
            'expires_at' => $substitution->expires_at->toIso8601ZuluString(),
        ], $line['pending_approval']);
    }

    /**
     * A pending question on a line of the order.
     *
     * @param  array<string, mixed>  $attributes
     */
    private function question(array $attributes = [], ?string $state = null): CustomerApproval
    {
        $factory = CustomerApproval::factory();
        if ($state !== null) {
            $factory = $factory->{$state}();
        }

        return $factory->create([
            'order_item_id' => fn (): string => OrderItem::factory()->for($this->order)->awaitingCustomer()->create(
                $state === 'substitution' ? ['substitution_policy_snapshot' => 'contact_before_substitution'] : []
            )->id,
            ...$attributes,
        ]);
    }

    /**
     * @param  array<string, mixed>|null  $body
     */
    private function decide(CustomerApproval $approval, string $decision, ?User $as = null, ?string $key = null, ?array $body = null): TestResponse
    {
        return $this->as($as ?? $this->customer)
            ->withHeader('Idempotency-Key', $key ?? (string) Str::uuid())
            ->postJson("/api/v1/customer/approvals/{$approval->id}/decision", $body ?? ['decision' => $decision]);
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
