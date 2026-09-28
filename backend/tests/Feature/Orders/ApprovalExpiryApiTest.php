<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\CustomerApproval;
use App\Models\Enums\ApprovalResolution;
use App\Models\Enums\ApprovalStatus;
use App\Models\Enums\CancellationReason;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\ItemRemovedReason;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\OrderItem;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * Expiry, the Operator's removal of an expired line, the approval attention
 * types and the board's `awaiting_customer`: `docs/09` sections 38 and 40,
 * `BR-APP-002`, `BR-APP-003`, `BR-APP-007`, `DL-54` (8), (13), `DL-55` (11)
 * and `DL-60`.
 */
final class ApprovalExpiryApiTest extends TestCase
{
    use RefreshDatabase;

    private User $operator;

    protected function setUp(): void
    {
        parent::setUp();

        Carbon::setTestNow(CarbonImmutable::parse('2026-09-28T10:00:00Z'));
        $this->operator = User::factory()->role(Role::Operator)->create();
    }

    protected function tearDown(): void
    {
        Carbon::setTestNow();

        parent::tearDown();
    }

    public function test_the_command_expires_every_overdue_approval_once(): void
    {
        $first = $this->question(minutesAgo: 31);
        $second = $this->question(minutesAgo: 30);
        $open = $this->question(minutesAgo: 29);

        $this->artisan('approvals:expire')->expectsOutput('Expired 2 approval(s).')->assertSuccessful();
        $this->artisan('approvals:expire')->expectsOutput('Expired 0 approval(s).')->assertSuccessful();

        $this->assertSame(ApprovalStatus::Expired, $first->fresh()?->status);
        $this->assertSame(ApprovalStatus::Expired, $second->fresh()?->status, 'At thirty minutes exactly (BR-APP-003).');
        $this->assertSame(ApprovalStatus::Pending, $open->fresh()?->status);
        $rows = OrderHistory::query()->where('event_type', OrderHistoryEvent::ApprovalExpired)->get();
        $this->assertCount(2, $rows);
        $this->assertSame([HistoryActorType::System], $rows->pluck('actor_type')->unique()->values()->all());
        $this->assertNull($first->fresh()->resolution, 'BR-APP-004: expiry is not consent.');
    }

    public function test_a_shopper_action_expires_the_orders_overdue_questions_first_and_no_one_elses(): void
    {
        $overdue = $this->question(minutesAgo: 31);
        $order = $overdue->order;
        $shopper = $order->currentShopperAssignment?->shopper;
        $other = OrderItem::factory()->for($order)->create();

        $elsewhere = $this->question(minutesAgo: 31);
        $this->withToken($shopper?->createToken('s')->plainTextToken ?? '')
            ->postJson("/api/v1/shopper/orders/{$elsewhere->order_id}/items/{$elsewhere->order_item_id}/unavailable")
            ->assertStatus(404);
        $this->assertSame(ApprovalStatus::Pending, $elsewhere->fresh()?->status, 'Another Shopper\'s order is left alone.');

        $this->withToken($shopper?->createToken('s')->plainTextToken ?? '')
            ->postJson("/api/v1/shopper/orders/{$order->id}/items/{$other->id}/unavailable")
            ->assertOk();

        $this->assertSame(ApprovalStatus::Expired, $overdue->fresh()?->status);
        $this->assertSame(1, OrderHistory::query()->where('order_id', $order->id)->where('event_type', OrderHistoryEvent::ApprovalExpired)->count());
    }

    public function test_the_operator_removes_the_line_of_an_expired_question_and_only_that(): void
    {
        $overdue = $this->question(minutesAgo: 31);
        OrderItem::factory()->for($overdue->order)->create();

        $data = $this->resolve($overdue, ['resolution' => 'remove_item', 'note' => 'Не дозвонились'])->assertOk()->json('data');

        $this->assertSame($overdue->order_id, $data['id']);
        $this->assertSame('removed', collect($data['items'])->firstWhere('id', $overdue->order_item_id)['status']);
        $approval = $overdue->fresh();
        $this->assertSame(ApprovalStatus::Expired, $approval?->status);
        $this->assertSame(ApprovalResolution::RemoveItem, $approval->resolution);
        $this->assertSame($this->operator->id, $approval->resolved_by_user_id);
        $this->assertSame(ItemRemovedReason::ApprovalExpired, $overdue->item->fresh()?->removed_reason_code);
        $resolved = OrderHistory::query()->where('event_type', OrderHistoryEvent::ApprovalResolved)->sole();
        $this->assertSame('Не дозвонились', $resolved->note);
        $this->assertSame($this->operator->id, $resolved->actor_user_id);
        $this->assertNull($resolved->to_status);

        // The same removal again writes nothing (DL-55 (2)).
        $this->resolve($overdue, ['resolution' => 'remove_item'])->assertOk();
        $this->assertSame(1, OrderHistory::query()->where('event_type', OrderHistoryEvent::ApprovalResolved)->count());

        $this->resolve($this->question(minutesAgo: 5), ['resolution' => 'remove_item'])
            ->assertStatus(409)->assertJsonPath('code', 'approval_not_expired');
        $this->resolve(CustomerApproval::factory()->approved()->create(), ['resolution' => 'remove_item'])
            ->assertStatus(409)->assertJsonPath('code', 'approval_already_resolved');

        $onACancelledOrder = CustomerApproval::factory()->expired()->create();
        $onACancelledOrder->order->forceFill(['status' => OrderStatus::Cancelled, 'cancelled_at' => now(), 'cancellation_reason_code' => CancellationReason::System])->save();
        $this->resolve($onACancelledOrder, ['resolution' => 'remove_item'])
            ->assertStatus(409)->assertJsonPath('code', 'order_state_conflict');
    }

    public function test_removing_the_last_line_cancels_the_order(): void
    {
        $overdue = $this->question(minutesAgo: 31);

        $this->resolve($overdue, ['resolution' => 'remove_item'])->assertOk()->assertJsonPath('data.status', 'cancelled');

        $row = OrderHistory::query()->where('event_type', OrderHistoryEvent::ApprovalResolved)->sole();
        $this->assertSame(OrderStatus::Shopping, $row->from_status);
        $this->assertSame(OrderStatus::Cancelled, $row->to_status);
        $this->assertSame(CancellationReason::NoItemsPurchased, $row->reason_code);
    }

    public function test_only_staff_resolve_and_only_by_removing_the_line(): void
    {
        $overdue = $this->question(minutesAgo: 31);

        $this->resolve($overdue, ['resolution' => 'approve'])->assertStatus(422)->assertJsonStructure(['errors' => ['resolution']]);
        $this->resolve($overdue, [])->assertStatus(422);
        foreach ([Role::Customer, Role::Shopper, Role::Courier, Role::Manager] as $role) {
            $this->resolve($overdue, ['resolution' => 'remove_item'], User::factory()->role($role)->create())->assertStatus(403);
        }
        $this->as($this->operator)->postJson('/api/v1/operations/approvals/'.Str::uuid().'/resolve-expired', ['resolution' => 'remove_item'])
            ->assertStatus(404);

        $this->resolve($overdue, ['resolution' => 'remove_item'], User::factory()->role(Role::Admin)->create())->assertOk();
    }

    public function test_the_attention_list_carries_an_unanswered_and_an_expired_question(): void
    {
        $waiting = $this->question(minutesAgo: 12);
        $second = CustomerApproval::factory()->create([
            'order_item_id' => OrderItem::factory()->for($waiting->order)->awaitingCustomer()->create()->id,
            'attention_at' => now()->subMinute(),
            'expires_at' => now()->addMinutes(19),
        ]);
        $expired = $this->question(minutesAgo: 35);
        $this->question(minutesAgo: 5);
        $cancelled = $this->question(minutesAgo: 35);
        $cancelled->order->forceFill(['status' => OrderStatus::Cancelled, 'cancelled_at' => now(), 'cancellation_reason_code' => CancellationReason::System])->save();

        $items = $this->as($this->operator)->getJson('/api/v1/operations/attention')->assertOk()->json('data');

        $this->assertSame([
            ['approval_expired', $expired->order_id, now()->subMinutes(5)->toIso8601ZuluString()],
            ['approval_pending', $waiting->order_id, now()->subMinutes(2)->toIso8601ZuluString()],
        ], array_map(static fn (array $item): array => [$item['type'], $item['order_id'], $item['since']], $items), 'One item per order and type, the longest waiting first.');
        $this->assertSame($waiting->order->currentShopperAssignment?->shopper_id, $items[1]['shopper']['id']);
        $this->assertNull($items[1]['courier']);
        $this->assertNotSame($second->id, $waiting->id);

        $this->assertIds([$waiting->order_id], ['attention' => 'approval_pending']);
        $this->assertIds([$expired->order_id], ['attention' => 'approval_expired']);
        $this->assertSame(2, $this->as($this->operator)->getJson('/api/v1/operations/summary')->json('data.attention_count'));

        // Removing the line takes it off the list.
        $this->resolve($expired, ['resolution' => 'remove_item'])->assertOk();
        $this->assertIds([], ['attention' => 'approval_expired']);
    }

    public function test_the_board_finds_what_waits_on_the_customer_and_shows_expiry_as_it_reads(): void
    {
        $waiting = $this->question(minutesAgo: 5);
        $overdue = $this->question(minutesAgo: 31);
        $quiet = Order::factory()->shopping()->create();

        $this->assertIds([$waiting->order_id], ['awaiting_customer' => 'true']);
        $this->assertEqualsCanonicalizing([$overdue->order_id, $quiet->id], $this->ids(['awaiting_customer' => 'false']));
        $this->as($this->operator)->getJson('/api/v1/operations/orders?awaiting_customer=yes')->assertStatus(422);

        $rows = collect($this->as($this->operator)->getJson('/api/v1/operations/orders')->json('data'))->keyBy('id');
        $this->assertSame(1, $rows[$waiting->order_id]['pending_approval_count']);
        $this->assertSame(0, $rows[$overdue->order_id]['pending_approval_count']);

        $approvals = $this->as($this->operator)->getJson("/api/v1/operations/orders/{$overdue->order_id}")->json('data.approvals');
        $this->assertSame('expired', $approvals[0]['status'], 'DL-54 (8): a read shows the expiry before anything wrote it.');

        $shopper = $overdue->order->currentShopperAssignment?->shopper;
        $line = collect($this->withToken($shopper?->createToken('s')->plainTextToken ?? '')
            ->getJson("/api/v1/shopper/orders/{$overdue->order_id}")->json('data.items'))->firstWhere('id', $overdue->order_item_id);
        $this->assertNull($line['pending_approval']);
    }

    /**
     * A pending question on a new order being shopped, asked some minutes ago.
     */
    private function question(int $minutesAgo): CustomerApproval
    {
        $asked = now()->subMinutes($minutesAgo);

        return CustomerApproval::factory()->create([
            'attention_at' => $asked->copy()->addMinutes(10),
            'expires_at' => $asked->copy()->addMinutes(30),
            'created_at' => $asked,
        ]);
    }

    /**
     * @param  array<string, mixed>  $body
     */
    private function resolve(CustomerApproval $approval, array $body, ?User $as = null): TestResponse
    {
        return $this->as($as ?? $this->operator)->postJson("/api/v1/operations/approvals/{$approval->id}/resolve-expired", $body);
    }

    /**
     * @param  list<string>  $expected
     * @param  array<string, string>  $filters
     */
    private function assertIds(array $expected, array $filters): void
    {
        $this->assertSame($expected, $this->ids($filters));
    }

    /**
     * @param  array<string, string>  $filters
     * @return list<string>
     */
    private function ids(array $filters): array
    {
        return array_column($this->as($this->operator)->getJson('/api/v1/operations/orders?'.http_build_query($filters))->assertOk()->json('data'), 'id');
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
