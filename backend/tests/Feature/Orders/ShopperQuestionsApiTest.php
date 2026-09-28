<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\Category;
use App\Models\CustomerApproval;
use App\Models\Enums\ApprovalStatus;
use App\Models\Enums\ApprovalType;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\Role;
use App\Models\Enums\SubstitutionPolicy;
use App\Models\Enums\SubstitutionResolution;
use App\Models\Enums\UnitCode;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\User;
use Carbon\CarbonImmutable;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * The Shopper's questions to the Customer and the replacement search:
 * `docs/09` sections 32 to 34, `docs/04` sections 14 to 19, `DL-54` (5),
 * (8), (17) and `DL-58`.
 *
 * The factory's line is a kg estimate at 16 000 market, 18 400 to the
 * Customer under 15 %, ordered 2.000; the estimate's ceiling is 21 160.
 */
final class ShopperQuestionsApiTest extends TestCase
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

    public function test_a_price_above_the_bound_is_put_to_the_customer_with_its_timers(): void
    {
        Carbon::setTestNow(CarbonImmutable::parse('2026-09-28T10:00:00Z'));
        $line = $this->line();

        $data = $this->ask($line, 'price-approval', ['actual_market_price_uzs' => 20000, 'note' => 'Подорожали'])->assertOk()->json('data');

        $approval = CustomerApproval::query()->sole();
        $this->assertSame(ApprovalType::PriceOverTolerance, $approval->type);
        $this->assertSame(ApprovalStatus::Pending, $approval->status);
        $this->assertSame(23000, $approval->proposed_customer_unit_price_uzs);
        $this->assertSame(20000, $approval->proposed_actual_market_price_uzs);
        $this->assertNull($approval->replacement_product_id);
        $this->assertSame('Подорожали', $approval->request_note);
        $this->assertSame($this->shopper->id, $approval->requested_by_user_id);
        $this->assertSame('2026-09-28T10:10:00Z', $approval->attention_at->toIso8601ZuluString());
        $this->assertSame('2026-09-28T10:30:00Z', $approval->expires_at->toIso8601ZuluString());
        $this->assertSame(OrderItemStatus::AwaitingCustomer, $line->fresh()?->status);
        $this->assertSame('awaiting_customer', $data['items'][0]['status']);
        $this->assertSame($approval->id, $data['items'][0]['pending_approval']['id']);

        $row = OrderHistory::query()->sole();
        $this->assertSame(OrderHistoryEvent::ApprovalRequested, $row->event_type);
        // jsonb keeps an object's keys in its own order, so the pairs are compared.
        $this->assertEquals(['approval_id' => $approval->id, 'item_id' => $line->id, 'type' => 'price_over_tolerance'], $row->details);

        // A second question on the awaiting line meets it resolved (BR-APP-011).
        $this->ask($line, 'price-approval', ['actual_market_price_uzs' => 21000])->assertStatus(409)->assertJsonPath('code', 'item_already_resolved');
        Carbon::setTestNow();
    }

    public function test_a_price_within_the_bound_or_for_a_fixed_original_needs_no_question(): void
    {
        // 18 400 × 1.15 = 21 160: at the ceiling, the Shopper simply buys.
        $this->ask($this->line(), 'price-approval', ['actual_market_price_uzs' => 18400])
            ->assertStatus(409)
            ->assertJsonPath('code', 'approval_not_needed')
            ->assertJsonPath('details.ceiling_customer_unit_price_uzs', 21160);

        $fixed = OrderItem::factory()->for($this->order)->for(Product::factory()->fixed())->create();
        $this->ask($fixed, 'price-approval', ['actual_market_price_uzs' => 99999])
            ->assertStatus(409)->assertJsonPath('code', 'approval_not_needed');

        $this->assertSame(0, CustomerApproval::query()->count());
    }

    public function test_a_price_question_about_the_replacement_names_it_and_meets_its_bound(): void
    {
        $replacement = Product::factory()->create();
        $line = $this->authorized($this->line(), $replacement, approvedPrice: 22000);

        // 19 131 × 1.15 = 22 000.65 → 22 001, above the 22 000 approved.
        $this->ask($line, 'price-approval', ['actual_market_price_uzs' => 19131])->assertOk();

        $approval = CustomerApproval::query()->sole();
        $this->assertSame($replacement->id, $approval->replacement_product_id);
        $this->assertSame($replacement->name_ru, $approval->replacement_name_ru_snapshot);
        $this->assertSame(22001, $approval->proposed_customer_unit_price_uzs);

        $this->ask($this->line(), 'price-approval', ['actual_market_price_uzs' => 20000, 'fulfilled_product_id' => $replacement->id])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['fulfilled_product_id']]);

        // 19 000 × 1.15 = 21 850: above the automatic 21 160, within the 22 000
        // the Customer approved for this replacement.
        $within = $this->authorized($this->line(), $replacement, approvedPrice: 22000);
        $this->ask($within, 'price-approval', ['actual_market_price_uzs' => 19000])
            ->assertStatus(409)
            ->assertJsonPath('code', 'approval_not_needed')
            ->assertJsonPath('details.ceiling_customer_unit_price_uzs', 22000);

        // Naming the original asks about the original, whatever is authorized.
        $original = $this->authorized($this->line(), $replacement);
        $this->ask($original, 'price-approval', ['actual_market_price_uzs' => 20000, 'fulfilled_product_id' => $original->product_id])->assertOk();
        $this->assertNull(CustomerApproval::query()->where('order_item_id', $original->id)->sole()->replacement_product_id);
    }

    public function test_a_similar_replacement_within_the_ceiling_is_authorized_at_once(): void
    {
        $line = $this->line();
        $replacement = Product::factory()->create();

        $data = $this->ask($line, 'substitution', ['replacement_product_id' => strtoupper($replacement->id), 'actual_market_price_uzs' => 18400])
            ->assertOk()->json('data.items.0');

        $this->assertSame('pending', $data['status']);
        $this->assertSame($replacement->id, $data['replacement']['product_id']);
        $this->assertSame('automatic', $data['replacement']['substitution_resolution']);
        $authorized = $line->fresh();
        $this->assertSame(SubstitutionResolution::Automatic, $authorized?->substitution_resolution);
        $this->assertSame($replacement->name_uz, $authorized->fulfilled_product_name_uz_snapshot);
        $this->assertSame(0, CustomerApproval::query()->count());

        $row = OrderHistory::query()->sole();
        $this->assertSame(OrderHistoryEvent::ItemSubstituted, $row->event_type);
        $this->assertEquals([
            'item_id' => $line->id,
            'product_id' => $replacement->id,
            'actual_market_price_uzs' => 18400,
            'proposed_customer_unit_price_uzs' => 21160,
        ], $row->details);

        // The same replacement again is a natural repeat within its bound, and
        // above it the purchase's answer (DL-58 (3)).
        $this->ask($line, 'substitution', ['replacement_product_id' => $replacement->id, 'actual_market_price_uzs' => 18000])->assertOk();
        $this->ask($line, 'substitution', ['replacement_product_id' => $replacement->id, 'actual_market_price_uzs' => 26087])
            ->assertStatus(409)
            ->assertJsonPath('code', 'customer_approval_required')
            ->assertJsonPath('details', [
                'approval_type' => 'price_over_tolerance',
                'ceiling_customer_unit_price_uzs' => 21160,
                'proposed_customer_unit_price_uzs' => 30000,
            ]);
        $this->assertSame(1, OrderHistory::query()->count());
        $this->assertSame(0, CustomerApproval::query()->count());
    }

    public function test_an_approved_replacement_proposed_again_meets_its_approved_price(): void
    {
        $replacement = Product::factory()->create();
        $line = $this->authorized($this->line(), $replacement, approvedPrice: 25000);

        // 20 000 × 1.15 = 23 000: above the automatic 21 160, within the 25 000
        // approved for it.
        $this->ask($line, 'substitution', ['replacement_product_id' => $replacement->id, 'actual_market_price_uzs' => 20000])->assertOk();
        // 21 740 × 1.15 = 25 001.
        $this->ask($line, 'substitution', ['replacement_product_id' => $replacement->id, 'actual_market_price_uzs' => 21740])
            ->assertStatus(409)
            ->assertJsonPath('details.ceiling_customer_unit_price_uzs', 25000);

        // Hidden from the catalog since, it is still the authorized one.
        $replacement->forceFill(['is_active' => false])->save();
        $this->ask($line, 'substitution', ['replacement_product_id' => $replacement->id, 'actual_market_price_uzs' => 20000])->assertOk();

        $this->assertSame(0, CustomerApproval::query()->count());
        $this->assertSame(0, OrderHistory::query()->count());
        $this->assertSame(OrderItemStatus::Pending, $line->fresh()?->status);
    }

    public function test_the_originals_approved_ceiling_raises_the_automatic_one_and_survives_a_replacement(): void
    {
        // BR-PRICE-005: an approved higher ceiling for the original is the
        // automatic ceiling too; 20 000 × 1.15 = 23 000.
        $line = $this->line(['approved_unit_price_ceiling_uzs' => 23000]);
        $replacement = Product::factory()->create();

        $this->ask($line, 'substitution', ['replacement_product_id' => $replacement->id, 'actual_market_price_uzs' => 20000])->assertOk();

        $authorized = $line->fresh();
        $this->assertSame(SubstitutionResolution::Automatic, $authorized?->substitution_resolution);
        $this->assertSame(23000, $authorized->approved_unit_price_ceiling_uzs, 'The original keeps its approved ceiling.');
    }

    public function test_a_replacement_above_the_ceiling_or_under_contact_before_is_put_to_the_customer(): void
    {
        $replacement = Product::factory()->create();

        $above = $this->line();
        $this->ask($above, 'substitution', ['replacement_product_id' => $replacement->id, 'actual_market_price_uzs' => 18401])->assertOk();
        $this->assertSame(OrderItemStatus::AwaitingCustomer, $above->fresh()?->status);
        $this->assertNull($above->fresh()->fulfilled_product_id, 'Nothing is authorized before the Customer answers.');

        $asked = $this->line(['substitution_policy_snapshot' => SubstitutionPolicy::ContactBefore]);
        $this->ask($asked, 'substitution', ['replacement_product_id' => $replacement->id, 'actual_market_price_uzs' => 11000, 'note' => 'Похожие'])->assertOk();

        $approvals = CustomerApproval::query()->orderBy('created_at')->orderBy('id')->get();
        $this->assertCount(2, $approvals);
        $question = $approvals->firstWhere('order_item_id', $asked->id);
        $this->assertSame(ApprovalType::Substitution, $question?->type);
        $this->assertSame($replacement->id, $question->replacement_product_id);
        $this->assertSame(UnitCode::Kg, $question->replacement_unit_code_snapshot);
        $this->assertSame(12650, $question->proposed_customer_unit_price_uzs);
        $this->assertSame(11000, $question->proposed_actual_market_price_uzs);
    }

    public function test_a_price_approved_for_one_replacement_never_authorizes_another(): void
    {
        // The Customer approved X at 25 000; Y at 23 000 is above the automatic
        // 21 160 and must be asked about, not authorized (DL-54 (5)).
        $line = $this->authorized($this->line(), Product::factory()->create(), approvedPrice: 25000);
        $other = Product::factory()->create();

        $this->ask($line, 'substitution', ['replacement_product_id' => $other->id, 'actual_market_price_uzs' => 20000])->assertOk();

        $asked = $line->fresh();
        $this->assertSame(OrderItemStatus::AwaitingCustomer, $asked?->status);
        $this->assertNotSame($other->id, $asked->fulfilled_product_id, 'The earlier replacement stays until the Customer answers.');
        $this->assertSame(25000, $asked->approved_replacement_price_uzs);
        $question = CustomerApproval::query()->sole();
        $this->assertSame(ApprovalType::Substitution, $question->type);
        $this->assertEquals(
            ['approval_id' => $question->id, 'item_id' => $line->id, 'type' => 'substitution'],
            OrderHistory::query()->where('event_type', OrderHistoryEvent::ApprovalRequested)->sole()->details
        );

        // A new automatic replacement takes the place of the approved one and
        // clears its approved price.
        $again = $this->authorized($this->line(), $approved = Product::factory()->create(), approvedPrice: 25000);
        $this->ask($again, 'substitution', ['replacement_product_id' => $other->id, 'actual_market_price_uzs' => 18000])->assertOk();
        $replaced = $again->fresh();
        $this->assertSame($other->id, $replaced?->fulfilled_product_id);
        $this->assertSame(SubstitutionResolution::Automatic, $replaced->substitution_resolution);
        $this->assertNull($replaced->approved_replacement_price_uzs);
        $this->assertSame($approved->id, OrderHistory::query()->where('event_type', OrderHistoryEvent::ItemSubstituted)->sole()->details['previous_product_id'] ?? null);
    }

    public function test_a_fixed_lines_replacement_meets_its_snapshot(): void
    {
        $fixed = OrderItem::factory()->for($this->order)->for(Product::factory()->fixed()->unit(UnitCode::Piece)->state(['market_price_uzs' => 3000]))
            ->create(['ordered_quantity' => '3']);
        $replacement = Product::factory()->unit(UnitCode::Piece)->create();

        $this->ask($fixed, 'substitution', ['replacement_product_id' => $replacement->id, 'actual_market_price_uzs' => 3001])->assertOk();

        $this->assertSame(OrderItemStatus::AwaitingCustomer, $fixed->fresh()?->status, 'BR-PRICE-005: 3 451 is above the fixed 3 450.');
    }

    public function test_a_replacement_is_refused_by_rule_unit_availability_or_for_being_the_original(): void
    {
        $replacement = Product::factory()->create();

        $removeRule = $this->line(['substitution_policy_snapshot' => SubstitutionPolicy::RemoveIfUnavailable]);
        $this->ask($removeRule, 'substitution', ['replacement_product_id' => $replacement->id, 'actual_market_price_uzs' => 16000])
            ->assertStatus(409)->assertJsonPath('code', 'substitution_not_allowed');

        $line = $this->line();
        $this->ask($line, 'substitution', ['replacement_product_id' => Product::factory()->unit(UnitCode::Piece)->create()->id, 'actual_market_price_uzs' => 16000])
            ->assertStatus(409)->assertJsonPath('code', 'replacement_unit_mismatch');

        $archived = Product::factory()->archived()->create();
        $this->ask($line, 'substitution', ['replacement_product_id' => $archived->id, 'actual_market_price_uzs' => 16000])
            ->assertStatus(409)
            ->assertJsonPath('code', 'product_unavailable')
            ->assertJsonPath('details.product_ids', [$archived->id]);

        $hidden = Product::factory()->for(Category::factory()->state(['is_active' => false]))->create();
        $this->ask($line, 'substitution', ['replacement_product_id' => $hidden->id, 'actual_market_price_uzs' => 16000])
            ->assertStatus(409)->assertJsonPath('code', 'product_unavailable');

        $this->ask($line, 'substitution', ['replacement_product_id' => $line->product_id, 'actual_market_price_uzs' => 16000])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['replacement_product_id']]);
        $this->ask($line, 'substitution', ['replacement_product_id' => $replacement->id])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['actual_market_price_uzs']]);

        $this->assertSame(0, OrderHistory::query()->count());
    }

    public function test_a_smaller_quantity_is_below_what_would_be_billed(): void
    {
        $line = $this->line(['ordered_quantity' => '5.000']);

        foreach (['5.000', '5.500', '0', '0.000', '-1', '1.2345'] as $refused) {
            $this->ask($line, 'reduced-quantity-approval', ['proposed_quantity' => $refused])
                ->assertStatus(422)->assertJsonStructure(['errors' => ['proposed_quantity']]);
        }

        $this->ask($line, 'reduced-quantity-approval', ['proposed_quantity' => '4.5', 'note' => 'Осталось 4,5 кг'])->assertOk();
        $approval = CustomerApproval::query()->sole();
        $this->assertSame(ApprovalType::ReducedQuantity, $approval->type);
        $this->assertSame('4.500', $approval->proposed_quantity);
        $this->assertNull($approval->proposed_customer_unit_price_uzs);

        $capped = $this->line(['ordered_quantity' => '5.000', 'approved_quantity_cap' => '4.000']);
        $this->ask($capped, 'reduced-quantity-approval', ['proposed_quantity' => '4.000'])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['proposed_quantity']]);

        $pieces = OrderItem::factory()->for($this->order)->for(Product::factory()->unit(UnitCode::Piece))->create(['ordered_quantity' => '3']);
        $this->ask($pieces, 'reduced-quantity-approval', ['proposed_quantity' => '1.5'])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['proposed_quantity']]);
        $this->ask($pieces, 'reduced-quantity-approval', ['proposed_quantity' => '2'])->assertOk();
    }

    public function test_the_board_shows_each_question_with_its_proposal(): void
    {
        $line = $this->line();
        $this->ask($line, 'price-approval', ['actual_market_price_uzs' => 20000])->assertOk();
        $approval = CustomerApproval::query()->sole();

        $board = $this->as(User::factory()->role(Role::Operator)->create())
            ->getJson("/api/v1/operations/orders/{$this->order->id}")->assertOk()->json('data.approvals');

        $this->assertSame([[
            'id' => $approval->id,
            'item_id' => $line->id,
            'type' => 'price_over_tolerance',
            'status' => 'pending',
            'proposed_customer_unit_price_uzs' => 23000,
            'proposed_actual_market_price_uzs' => 20000,
            'proposed_quantity' => null,
            'replacement' => null,
            'request_note' => null,
            'requested_by' => ['id' => $this->shopper->id, 'full_name' => $this->shopper->full_name],
            'attention_at' => $approval->attention_at->toIso8601ZuluString(),
            'expires_at' => $approval->expires_at->toIso8601ZuluString(),
            'resolution' => null,
            'resolved_by' => null,
            'resolved_at' => null,
            'created_at' => $approval->created_at->toIso8601ZuluString(),
        ]], $board);
    }

    public function test_the_board_shows_a_replacement_and_a_quantity_in_its_unit(): void
    {
        $replacement = Product::factory()->create();
        $this->ask($this->line(['substitution_policy_snapshot' => SubstitutionPolicy::ContactBefore]), 'substitution', [
            'replacement_product_id' => $replacement->id,
            'actual_market_price_uzs' => 11000,
        ])->assertOk();
        $pieces = OrderItem::factory()->for($this->order)->for(Product::factory()->unit(UnitCode::Piece))->create(['ordered_quantity' => '3']);
        $this->ask($pieces, 'reduced-quantity-approval', ['proposed_quantity' => '2'])->assertOk();

        $board = collect($this->as(User::factory()->role(Role::Operator)->create())
            ->getJson("/api/v1/operations/orders/{$this->order->id}")->assertOk()->json('data.approvals'));

        $this->assertSame(
            ['product_id' => $replacement->id, 'name_uz' => $replacement->name_uz, 'name_ru' => $replacement->name_ru],
            $board->firstWhere('type', 'substitution')['replacement']
        );
        $this->assertSame('2', $board->firstWhere('type', 'reduced_quantity')['proposed_quantity']);
        $this->assertEquals(
            ['approval_id' => $board->firstWhere('type', 'reduced_quantity')['id'], 'item_id' => $pieces->id, 'type' => 'reduced_quantity'],
            OrderHistory::query()->where('event_type', OrderHistoryEvent::ApprovalRequested)->latest('created_at')->latest('id')->first()?->details
        );
    }

    public function test_only_the_shopper_of_the_order_asks_about_its_own_lines(): void
    {
        $line = $this->line();
        $elsewhere = OrderItem::factory()->for(Order::factory()->shopping())->create();

        foreach ([Role::Customer, Role::Courier, Role::Operator, Role::Admin] as $role) {
            $this->as(User::factory()->role($role)->create())
                ->postJson("/api/v1/shopper/orders/{$line->order_id}/items/{$line->id}/price-approval", ['actual_market_price_uzs' => 20000])
                ->assertStatus(403);
        }

        foreach (['price-approval' => ['actual_market_price_uzs' => 20000], 'reduced-quantity-approval' => ['proposed_quantity' => '1.000'],
            'substitution' => ['replacement_product_id' => Product::factory()->create()->id, 'actual_market_price_uzs' => 16000]] as $action => $body) {
            $this->as($this->shopper)->postJson("/api/v1/shopper/orders/{$this->order->id}/items/{$elsewhere->id}/{$action}", $body)
                ->assertStatus(404);
        }
        $this->as($this->shopper)->getJson("/api/v1/shopper/orders/{$this->order->id}/items/{$elsewhere->id}/replacements")->assertStatus(404);

        $this->assertSame(0, CustomerApproval::query()->count());
    }

    public function test_the_replacement_search_lists_the_products_of_the_lines_unit(): void
    {
        $line = $this->line();
        $cherry = Product::factory()->create(['name_uz' => 'Olcha', 'name_ru' => 'Вишня', 'market_price_uzs' => 17000, 'sort_order' => 1]);
        $apple = Product::factory()->create(['name_uz' => 'Olma', 'name_ru' => 'Яблоко', 'sort_order' => 2]);
        Product::factory()->unit(UnitCode::Piece)->create(['name_ru' => 'Вишнёвый пирог']);
        Product::factory()->archived()->create(['name_ru' => 'Вишня старая']);
        Product::factory()->for(Category::factory()->state(['is_active' => false]))->create(['name_ru' => 'Вишня скрытая']);

        $all = $this->as($this->shopper)->getJson($this->replacementsUrl($line))->assertOk();
        $ids = array_column($all->json('data'), 'id');
        $this->assertContains($cherry->id, $ids);
        $this->assertContains($apple->id, $ids);
        $this->assertNotContains($line->product_id, $ids, 'The original is no replacement.');
        $this->assertSame(2, $all->json('meta.pagination.total'));

        $found = $this->as($this->shopper)->getJson($this->replacementsUrl($line).'?search=ВИШН')->assertOk()->json('data');
        $this->assertSame([[
            'id' => $cherry->id,
            'name_uz' => 'Olcha',
            'name_ru' => 'Вишня',
            'unit_code' => 'kg',
            'price_mode' => 'estimate',
            'market_price_uzs' => 17000,
            'image_url' => null,
        ]], $found);

        $removed = $this->line();
        $removed->forceFill(['status' => OrderItemStatus::Removed, 'removed_reason_code' => 'customer_removed', 'removed_at' => now(), 'line_total_uzs' => 0])->save();
        $this->as($this->shopper)->getJson($this->replacementsUrl($removed))->assertStatus(404);
        $this->as(User::factory()->role(Role::Shopper)->create())->getJson($this->replacementsUrl($line))->assertStatus(404);
        $this->as($this->shopper)->getJson($this->replacementsUrl($line).'?search='.str_repeat('a', 101))->assertStatus(422);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function line(array $attributes = []): OrderItem
    {
        return OrderItem::factory()->for($this->order)->create($attributes);
    }

    private function authorized(OrderItem $line, Product $replacement, ?int $approvedPrice = null): OrderItem
    {
        $line->forceFill([
            'fulfilled_product_id' => $replacement->id,
            'fulfilled_product_name_uz_snapshot' => $replacement->name_uz,
            'fulfilled_product_name_ru_snapshot' => $replacement->name_ru,
            'fulfilled_unit_code_snapshot' => $line->unit_code_snapshot,
            'substitution_resolution' => $approvedPrice === null ? SubstitutionResolution::Automatic : SubstitutionResolution::Approved,
            'approved_replacement_price_uzs' => $approvedPrice,
        ])->save();

        return $line;
    }

    /**
     * @param  array<string, mixed>  $body
     */
    private function ask(OrderItem $line, string $action, array $body): TestResponse
    {
        return $this->as($this->shopper)->postJson("/api/v1/shopper/orders/{$line->order_id}/items/{$line->id}/{$action}", $body);
    }

    private function replacementsUrl(OrderItem $line): string
    {
        return "/api/v1/shopper/orders/{$line->order_id}/items/{$line->id}/replacements";
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
