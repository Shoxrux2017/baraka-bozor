<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\Enums\AssignmentEndReason;
use App\Models\Enums\CancellationReason;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\OrderItem;
use App\Models\OrderShopperAssignment;
use App\Models\Product;
use App\Models\User;
use Carbon\CarbonImmutable;
use Carbon\CarbonInterface;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * The board of the Operator and the Admin, `docs/09` section 38 and `DL-37`
 * (16): the list with its filters and search, an order's detail, the summary
 * for the day in `Asia/Tashkent`, and the attention list.
 */
final class OperationsBoardApiTest extends TestCase
{
    use RefreshDatabase;

    private User $operator;

    protected function setUp(): void
    {
        parent::setUp();

        $this->operator = User::factory()->role(Role::Operator)->create();
        $this->travelTo(CarbonImmutable::parse('2026-09-27 12:00:00', 'Asia/Tashkent'));
    }

    public function test_only_the_operator_and_the_admin_see_the_board(): void
    {
        $order = Order::factory()->create();

        foreach ([Role::Operator, Role::Admin] as $role) {
            $as = $this->as(User::factory()->role($role)->create());
            foreach (['orders', 'orders/'.$order->id, 'summary', 'attention'] as $path) {
                $as->getJson('/api/v1/operations/'.$path)->assertOk();
            }
        }
        foreach ([Role::Customer, Role::Shopper, Role::Courier, Role::Manager] as $role) {
            $this->as(User::factory()->role($role)->create())->getJson('/api/v1/operations/orders')->assertStatus(403);
        }
    }

    public function test_the_list_is_newest_first_with_what_a_row_needs(): void
    {
        $older = Order::factory()->create(['created_at' => now()->subHour()]);
        OrderItem::factory()->for($older)->for(Product::factory()->create(['market_price_uzs' => 16000]))->create(['ordered_quantity' => '3.000']);
        $newer = Order::factory()->shoppingAssigned()->create();

        $rows = $this->board()->assertOk()->json('data');

        $this->assertSame([$newer->id, $older->id], array_column($rows, 'id'));
        $this->assertSame(
            ['id', 'order_number', 'created_at', 'status', 'payment_method', 'customer', 'item_count', 'total_uzs', 'total_kind', 'shopper', 'is_self_order'],
            array_keys($rows[0])
        );
        $this->assertNotNull($rows[0]['shopper']);
        $this->assertSame(1, $rows[1]['item_count']);
        $this->assertSame(55200 + 5000 + 15000, $rows[1]['total_uzs']);
        $this->assertSame($older->recipient_phone_snapshot, $rows[1]['customer']['phone']);
    }

    public function test_each_filter_narrows_the_list(): void
    {
        $new = Order::factory()->create();
        $assigned = Order::factory()->shoppingAssigned()->create();
        $online = Order::factory()->online()->create();
        // Eloquent saves an instant without its zone, so each is handed over in UTC.
        // 23:30 in Tashkent is 18:30 UTC, the 26th in both.
        $yesterday = Order::factory()->create(['created_at' => CarbonImmutable::parse('2026-09-26 23:30:00', 'Asia/Tashkent')->utc()]);
        // 00:30 in Tashkent is 19:30 UTC the day before: the 27th in Tashkent only.
        $pastMidnight = Order::factory()->create(['created_at' => CarbonImmutable::parse('2026-09-27 00:30:00', 'Asia/Tashkent')->utc()]);
        $shopper = $assigned->currentShopperAssignment?->shopper_id;

        $this->assertIds([$assigned->id], ['status' => 'shopping_assigned']);
        $this->assertIds([$assigned->id], ['shopper_id' => $shopper]);
        $this->assertIds([$online->id], ['payment_method' => 'online']);
        $this->assertIds([$yesterday->id], ['from' => '2026-09-26', 'to' => '2026-09-26']);
        $this->assertIds([$yesterday->id], ['to' => '2026-09-26']);
        $this->assertIds([$online->id, $assigned->id, $new->id, $pastMidnight->id], ['from' => '2026-09-27', 'to' => '2026-09-27']);

        // A Shopper replaced on an order no longer finds it.
        $assigned->currentShopperAssignment?->forceFill(['ended_at' => now(), 'ended_reason' => AssignmentEndReason::Reassigned])->save();
        OrderShopperAssignment::factory()->create(['order_id' => $assigned->id]);
        $this->assertIds([], ['shopper_id' => $shopper]);

        $this->board(['status' => 'approval_required'])->assertStatus(422);
        $this->board(['from' => '2026-09-27', 'to' => '2026-09-26'])->assertStatus(422);
        $this->board(['attention' => 'everything'])->assertStatus(422);
        // Days before local time existed in Tashkent have no instant PostgreSQL takes.
        $this->board(['from' => '0001-01-01'])->assertStatus(422);
        $this->board(['to' => '0001-01-01'])->assertStatus(422);
        $this->board(['from' => '3000-01-01'])->assertStatus(422);
    }

    public function test_the_search_finds_an_order_by_number_phone_or_name(): void
    {
        $customer = User::factory()->customer()->create(['phone' => '+998901112233']);
        $aziza = Order::factory()->create(['customer_id' => $customer->id, 'recipient_name_snapshot' => 'Aziza Karimova']);
        // A phone that holds no order number of this run, so a number search finds Aziza alone.
        $bobur = User::factory()->customer()->create(['phone' => '+998900000000']);
        $other = Order::factory()->create(['customer_id' => $bobur->id, 'recipient_name_snapshot' => 'Bobur Aliyev']);
        $number = (string) $aziza->fresh()?->order_number;

        $this->assertIds([$aziza->id], ['search' => $number]);
        $this->assertIds([$aziza->id], ['search' => '1112233']);
        $this->assertIds([$aziza->id], ['search' => 'aziza']);
        $this->assertIds([$other->id], ['search' => 'ALIYEV']);
        // The term's wildcards are its own characters.
        $this->assertIds([], ['search' => '%']);
        $this->assertIds([], ['search' => '_']);
        $this->assertIds([], ['search' => '50%']);
    }

    public function test_the_name_search_reads_the_apostrophe_and_yo_however_they_were_typed(): void
    {
        $gayrat = Order::factory()->create(['recipient_name_snapshot' => 'Gʻayrat To’xtayev']);
        $alyona = Order::factory()->create(['recipient_name_snapshot' => 'Алёна Смирнова']);
        $gulnora = Order::factory()->create(['recipient_name_snapshot' => 'G’ulnora']);

        $this->assertIds([$gayrat->id], ['search' => "g'ayrat"]);
        $this->assertIds([$gayrat->id], ['search' => 'to`xtayev']);
        $this->assertIds([$gulnora->id], ['search' => 'Gʻulnora']);
        $this->assertIds([$alyona->id], ['search' => 'алена']);
        $this->assertIds([$alyona->id], ['search' => 'АЛЁНА']);
    }

    public function test_the_detail_carries_the_lines_assignments_and_history(): void
    {
        $order = Order::factory()->shoppingAssigned()->create();
        OrderItem::factory()->for($order)->for(Product::factory()->create(['market_price_uzs' => 16000]))->create();
        $edit = new OrderHistory;
        $edit->forceFill([
            'order_id' => $order->id,
            'event_type' => OrderHistoryEvent::Edited,
            'actor_type' => HistoryActorType::User,
            'actor_user_id' => $order->customer_id,
            'details' => ['delivery_time_note' => ['before' => null, 'after' => 'after 18:00']],
        ])->save();

        $data = $this->as($this->operator)->getJson('/api/v1/operations/orders/'.$order->id)->assertOk()->json('data');

        $this->assertSame(16000, $data['items'][0]['market_price_uzs']);
        $this->assertSame('15.00', $data['items'][0]['markup_percent']);
        $this->assertCount(1, $data['shopper_assignments']);
        $this->assertFalse($data['shopper_assignments'][0]['is_self_order']);
        $this->assertCount(1, $data['history']);
        $this->assertSame('edited', $data['history'][0]['event_type']);
        $this->assertSame(['id' => $order->customer_id, 'role' => 'customer', 'full_name' => $order->customer->full_name], $data['history'][0]['actor']);
        $this->assertEquals(['delivery_time_note' => ['before' => null, 'after' => 'after 18:00']], $data['history'][0]['details']);
        $this->assertSame([], $data['courier_assignments']);
        $this->assertSame([], $data['approvals']);
        $this->assertNull($data['payment']);
        $this->assertSame([], $data['refunds']);
        $this->assertSame($order->recipient_phone_snapshot, $data['customer']['phone']);

        $this->as($this->operator)->getJson('/api/v1/operations/orders/'.(string) Str::uuid())->assertStatus(404);
    }

    public function test_the_summary_counts_open_orders_whatever_their_day_and_todays_ends_by_their_instants(): void
    {
        // Eloquent saves an instant without its zone, so each is handed over in UTC.
        // Placed last night, collected this morning: still open today.
        Order::factory()->create(['created_at' => CarbonImmutable::parse('2026-09-26 23:40:00', 'Asia/Tashkent')->utc()]);
        Order::factory()->shoppingAssigned()->create();
        // Completed at 00:30 in Tashkent — 19:30 UTC the day before — is today's.
        Order::factory()->completed()->create(['completed_at' => CarbonImmutable::parse('2026-09-27 00:30:00', 'Asia/Tashkent')->utc()]);
        // Completed at 23:30 yesterday in Tashkent is not.
        Order::factory()->completed()->create(['completed_at' => CarbonImmutable::parse('2026-09-26 23:30:00', 'Asia/Tashkent')->utc()]);
        Order::factory()->cancelled()->create(['cancelled_at' => now()]);
        Order::factory()->cancelled(CancellationReason::System)->create(['cancelled_at' => now()->subDays(2)]);

        $data = $this->as($this->operator)->getJson('/api/v1/operations/summary')->assertOk()->json('data');

        $this->assertSame('2026-09-27', $data['day']);
        $this->assertSame(1, $data['open_by_status']['new']);
        $this->assertSame(1, $data['open_by_status']['shopping_assigned']);
        $this->assertSame(0, $data['open_by_status']['on_the_way']);
        $this->assertArrayNotHasKey('completed', $data['open_by_status']);
        $this->assertSame(1, $data['completed_today']);
        $this->assertSame(1, $data['cancelled_today']);
        $this->assertSame(120000, $data['sales_today_uzs']);
        $this->assertSame(0, $data['attention_count']);
    }

    public function test_a_self_order_is_on_the_attention_list_until_the_order_ends_or_the_shopper_changes(): void
    {
        // An ordinary assignment is never on the list.
        Order::factory()->shoppingAssigned()->create();
        $replaced = $this->selfOrder(now()->subHour());
        $cancelled = $this->selfOrder(now()->subMinutes(30));
        $ended = $this->selfOrder(now()->subMinutes(10));

        $items = $this->as($this->operator)->getJson('/api/v1/operations/attention')->assertOk()->json('data');
        $this->assertSame([$replaced->id, $cancelled->id, $ended->id], array_column($items, 'order_id'), 'The longest-waiting first.');
        $this->assertSame(['type', 'order_id', 'order_number', 'since', 'shopper'], array_keys($items[0]));
        $this->assertSame('self_order', $items[0]['type']);
        $this->assertSame($replaced->fresh()?->order_number, $items[0]['order_number']);
        $this->assertSame(now()->subHour()->toIso8601ZuluString(), $items[0]['since']);
        $this->assertIds([$ended->id, $cancelled->id, $replaced->id], ['attention' => 'self_order']);
        $this->as($this->operator)->getJson('/api/v1/operations/summary')->assertJsonPath('data.attention_count', 3);

        // The Shopper is replaced by one who is not the Customer.
        $replaced->currentShopperAssignment?->forceFill(['ended_at' => now(), 'ended_reason' => AssignmentEndReason::Reassigned])->save();
        OrderShopperAssignment::factory()->create(['order_id' => $replaced->id, 'is_self_order' => false]);
        // The Customer cancels the order.
        $this->withToken($cancelled->customer->createToken('t')->plainTextToken)
            ->withHeader('Idempotency-Key', (string) Str::uuid())
            ->postJson('/api/v1/customer/orders/'.$cancelled->id.'/cancel')
            ->assertOk();
        // The order ends while its assignment is still current.
        $ended->forceFill(['status' => 'cancelled', 'cancelled_at' => now(), 'cancellation_reason_code' => CancellationReason::System])->save();

        $this->assertSame([], $this->as($this->operator)->getJson('/api/v1/operations/attention')->json('data'));
        $this->assertIds([], ['attention' => 'self_order']);
        $this->as($this->operator)->getJson('/api/v1/operations/summary')->assertJsonPath('data.attention_count', 0);
    }

    private function selfOrder(CarbonInterface $assignedAt): Order
    {
        $order = Order::factory()->create();
        OrderShopperAssignment::factory()->create(['order_id' => $order->id, 'is_self_order' => true, 'assigned_at' => $assignedAt]);
        $order->forceFill(['status' => 'shopping_assigned'])->save();

        return $order;
    }

    /**
     * @param  list<string>  $ids
     * @param  array<string, mixed>  $filters
     */
    private function assertIds(array $ids, array $filters): void
    {
        $this->assertSame($ids, array_column($this->board($filters)->assertOk()->json('data'), 'id'), json_encode($filters) ?: '');
    }

    /**
     * @param  array<string, mixed>  $filters
     */
    private function board(array $filters = []): TestResponse
    {
        return $this->as($this->operator)->getJson('/api/v1/operations/orders?'.http_build_query($filters));
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
