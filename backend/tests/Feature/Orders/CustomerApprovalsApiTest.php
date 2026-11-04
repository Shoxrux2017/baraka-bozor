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
use App\Models\ProductImage;
use App\Models\User;
use App\Modules\Catalog\ProductImages;
use App\Modules\Orders\Http\Resources\CustomerOrderResource;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
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

    public function test_the_count_and_the_lines_read_a_question_at_one_instant(): void
    {
        Carbon::setTestNow(CarbonImmutable::parse('2026-09-28T10:00:00Z'));
        $question = $this->question(['attention_at' => now()->subMinutes(20), 'expires_at' => now()->addSecond()]);
        $order = $this->order->fresh()->load(['items', 'currentShopperAssignment', 'approvals', 'livePayment', 'latestCancellationRequest']);

        // A clock a second later at every reading: the question expires
        // between the first reading and any other.
        $readings = 0;
        Carbon::setTestNow(static function () use (&$readings): CarbonImmutable {
            return CarbonImmutable::parse('2026-09-28T10:00:00Z')->addSeconds($readings++);
        });
        $data = (new CustomerOrderResource($order))->toArray(request());
        Carbon::setTestNow();

        $line = collect($data['items'])->firstWhere('id', $question->order_item_id);
        $this->assertSame(1, $data['pending_approval_count']);
        $this->assertSame($question->id, $line['pending_approval']['id']);
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
                'image_url' => null,
            ],
            'request_note' => null,
            'expires_at' => $substitution->expires_at->toIso8601ZuluString(),
            'estimate_if_approved_uzs' => 25300,
            'change_if_approved_uzs' => 25300 - $line['line_total_uzs'],
            'change_if_rejected_uzs' => -$line['line_total_uzs'],
        ], $line['pending_approval']);
    }

    /**
     * @return array<string, array{0: string|null, 1: string|null, 2: int, 3: int, 4: int}>
     */
    public static function whatEachAnswerDoes(): array
    {
        return [
            'a price question' => [null, null, 25300, 5300, -20000],
            'a reduced quantity' => ['reducedQuantity', null, 15000, -5000, -20000],
            'a substitution' => ['substitution', null, 25300, 5300, -20000],
            'a reduced quantity after an earlier price yes' => ['reducedQuantity', '11000', 16500, -5500, -22000],
        ];
    }

    #[DataProvider('whatEachAnswerDoes')]
    public function test_a_question_says_what_each_answer_does_to_the_line(?string $state, ?string $earlierCeiling, int $estimate, int $change, int $rejected): void
    {
        $approval = $this->yesOn($state);
        if ($earlierCeiling !== null) {
            $approval->item->forceFill(['approved_unit_price_ceiling_uzs' => (int) $earlierCeiling])->save();
        }

        $question = $this->as($this->customer)->getJson("/api/v1/customer/orders/{$this->order->id}")->assertOk()->json('data.items.0.pending_approval');

        $this->assertSame($estimate, $question['estimate_if_approved_uzs']);
        $this->assertSame($change, $question['change_if_approved_uzs']);
        $this->assertSame($rejected, $question['change_if_rejected_uzs']);
        $this->assertSame(OrderItemStatus::AwaitingCustomer, $approval->item->fresh()->status, 'A read writes nothing.');
        $this->assertNull($approval->item->fresh()->approved_quantity_cap);
    }

    #[DataProvider('kindsOfYes')]
    public function test_the_money_effect_is_what_the_answer_then_shows(?string $state): void
    {
        $approval = $this->yesOn($state);
        $read = fn (): array => $this->as($this->customer)->getJson("/api/v1/customer/orders/{$this->order->id}")->assertOk()->json('data.items.0');
        $before = $read();

        $this->decide($approval, 'approve')->assertOk();

        $after = $read();
        $this->assertSame($before['pending_approval']['change_if_approved_uzs'], $after['line_total_uzs'] - $before['line_total_uzs']);
        $this->assertSame($before['pending_approval']['estimate_if_approved_uzs'], $after['line_total_uzs']);
    }

    public function test_the_replacement_shows_its_picture(): void
    {
        $with = $this->yesOn('substitution');
        $image = ProductImage::factory()->create(['product_id' => $with->replacement_product_id]);

        $url = $this->as($this->customer)->getJson("/api/v1/customer/orders/{$this->order->id}")->assertOk()->json('data.items.0.pending_approval.replacement.image_url');
        $this->assertSame(ProductImages::url($image), $url);

        $image->delete();
        $url = $this->as($this->customer)->getJson("/api/v1/customer/orders/{$this->order->id}")->assertOk()->json('data.items.0.pending_approval.replacement.image_url');
        $this->assertNull($url);
    }

    /**
     * @return array<string, array{0: string|null, 1: int, 2: array{customer_unit_price_uzs: int|null, quantity: string|null}}>
     */
    public static function kindsOfYes(): array
    {
        return [
            'a price question' => [null, 25300, ['customer_unit_price_uzs' => 12650, 'quantity' => null]],
            'a reduced quantity' => ['reducedQuantity', 15000, ['customer_unit_price_uzs' => null, 'quantity' => '1.500']],
            'a substitution' => ['substitution', 25300, ['customer_unit_price_uzs' => 12650, 'quantity' => null]],
        ];
    }

    /**
     * @param  array{customer_unit_price_uzs: int|null, quantity: string|null}  $agreed
     */
    #[DataProvider('kindsOfYes')]
    public function test_a_yes_moves_the_line_to_what_was_agreed(?string $state, int $lineTotal, array $agreed): void
    {
        $approval = $this->yesOn($state);

        $this->decide($approval, 'approve')->assertOk();

        $data = $this->as($this->customer)->getJson("/api/v1/customer/orders/{$this->order->id}")->assertOk()->json('data');
        $line = $data['items'][0];
        $this->assertSame($lineTotal, $line['line_total_uzs']);
        $this->assertSame($agreed, $line['agreed']);
        $this->assertSame($lineTotal, $data['totals']['merchandise_subtotal_uzs']);
        if ($state === 'substitution') {
            $this->assertSame($approval->replacement_name_ru_snapshot, $line['replacement']['name_ru']);
        }
    }

    #[DataProvider('kindsOfYes')]
    public function test_the_list_and_the_order_agree_on_the_estimate_in_force(?string $state): void
    {
        $this->decide($this->yesOn($state), 'approve')->assertOk();

        $detail = $this->as($this->customer)->getJson("/api/v1/customer/orders/{$this->order->id}")->assertOk()->json('data.totals.total_uzs');
        $listed = $this->as($this->customer)->getJson('/api/v1/customer/orders')->assertOk()->json('data.0.total_uzs');

        $this->assertSame($detail, $listed);
    }

    public function test_an_automatic_replacement_keeps_the_snapshot_estimate(): void
    {
        $line = $this->twoKilosAtTenThousand();
        $line->forceFill(['approved_unit_price_ceiling_uzs' => 12650])->save();
        $replacement = Product::factory()->create();
        $line->forceFill([
            'fulfilled_product_id' => $replacement->id,
            'fulfilled_product_name_uz_snapshot' => $replacement->name_uz,
            'fulfilled_product_name_ru_snapshot' => $replacement->name_ru,
            'fulfilled_unit_code_snapshot' => $line->unit_code_snapshot,
            'substitution_resolution' => SubstitutionResolution::Automatic,
        ])->save();

        $item = $this->as($this->customer)->getJson("/api/v1/customer/orders/{$this->order->id}")->assertOk()->json('data.items.0');

        $this->assertSame(20000, $item['line_total_uzs']);
        $this->assertNull($item['agreed']);
    }

    public function test_agreed_is_shown_on_an_open_line_and_not_on_a_bought_one(): void
    {
        $bought = OrderItem::factory()->for($this->order)->purchased()->create([
            'approved_quantity_cap' => '1.500',
            'purchased_quantity' => '1.500',
            'billable_quantity' => '1.500',
            'line_total_uzs' => fn (array $attributes): int => intdiv($attributes['customer_unit_price_uzs_snapshot'] * 3, 2),
        ]);
        $awaiting = OrderItem::factory()->for($this->order)->awaitingCustomer()->create(['approved_quantity_cap' => '1.500']);

        $items = collect($this->as($this->customer)->getJson("/api/v1/customer/orders/{$this->order->id}")->assertOk()->json('data.items'));

        $this->assertNull($items->firstWhere('id', $bought->id)['agreed']);
        $this->assertSame(
            ['customer_unit_price_uzs' => null, 'quantity' => '1.500'],
            $items->firstWhere('id', $awaiting->id)['agreed'],
        );
    }

    /**
     * An open question on a line of 2 kg at 10 000, and the line.
     */
    private function yesOn(?string $state): CustomerApproval
    {
        $line = $this->twoKilosAtTenThousand();

        $factory = match ($state) {
            'reducedQuantity' => CustomerApproval::factory()->reducedQuantity('1.500'),
            'substitution' => CustomerApproval::factory()->substitution(),
            default => CustomerApproval::factory()->state(['proposed_customer_unit_price_uzs' => 12650]),
        };

        return $factory->create(['order_item_id' => $line->id]);
    }

    private function twoKilosAtTenThousand(): OrderItem
    {
        return OrderItem::factory()->for($this->order)->awaitingCustomer()->create([
            'unit_code_snapshot' => 'kg',
            'price_mode_snapshot' => 'estimate',
            'customer_unit_price_uzs_snapshot' => 10000,
            'ordered_quantity' => '2.000',
        ]);
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
