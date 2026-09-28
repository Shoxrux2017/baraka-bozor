<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use App\Models\Enums\Role;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\Database\AssertsDatabaseRejections;
use Tests\Support\Database\ReadsPostgresCatalog;
use Tests\TestCase;

/**
 * `customer_approvals`, as `docs/08-database.md` Section 18 names it, with the
 * status `cancelled` (`DL-54` (8)): one pending approval per line
 * (`BR-APP-011`), a proposal shaped by its type (`BR-APP-001`), and the
 * columns each status implies.
 *
 * Each check is proven by a row only it refuses; PostgreSQL evaluates checks
 * in name order, so such a row satisfies every check named before it.
 */
final class CustomerApprovalsTableTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    private const TABLE = 'customer_approvals';

    private OrderItem $item;

    private User $shopper;

    protected function setUp(): void
    {
        parent::setUp();

        $order = Order::factory()->shopping()->create();
        $this->item = OrderItem::factory()->for($order)->awaitingCustomer()->create();
        $this->shopper = User::query()->findOrFail($order->currentShopperAssignment?->shopper_id);
    }

    /**
     * A pending price question: 20 000 paid, 23 000 to the Customer.
     *
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function row(array $overrides = []): array
    {
        return array_merge([
            'id' => (string) Str::uuid(),
            'order_id' => $this->item->order_id,
            'order_item_id' => $this->item->id,
            'type' => 'price_over_tolerance',
            'status' => 'pending',
            'requested_by_user_id' => $this->shopper->id,
            'proposed_customer_unit_price_uzs' => 23000,
            'proposed_actual_market_price_uzs' => 20000,
            'attention_at' => now()->addMinutes(10),
            'expires_at' => now()->addMinutes(30),
            'created_at' => now(),
            'updated_at' => now(),
        ], $overrides);
    }

    /**
     * A replacement and its snapshots.
     *
     * @return array<string, mixed>
     */
    private function replacement(): array
    {
        $product = Product::factory()->create();

        return [
            'replacement_product_id' => $product->id,
            'replacement_name_uz_snapshot' => $product->name_uz,
            'replacement_name_ru_snapshot' => $product->name_ru,
            'replacement_unit_code_snapshot' => 'kg',
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function resolvedBy(User $user, string $resolution): array
    {
        return ['resolution' => $resolution, 'resolved_by_user_id' => $user->id, 'resolved_at' => now()];
    }

    public function test_it_has_exactly_the_columns_the_schema_names(): void
    {
        $this->assertColumns(self::TABLE, [
            'id' => ['uuid', false],
            'order_id' => ['uuid', false],
            'order_item_id' => ['uuid', false],
            'type' => ['character varying', false, 24],
            'status' => ['character varying', false, 16],
            'requested_by_user_id' => ['uuid', false],
            'proposed_customer_unit_price_uzs' => ['bigint', true],
            'proposed_actual_market_price_uzs' => ['bigint', true],
            'proposed_quantity' => ['numeric', true],
            'replacement_product_id' => ['uuid', true],
            'replacement_name_uz_snapshot' => ['character varying', true, 160],
            'replacement_name_ru_snapshot' => ['character varying', true, 160],
            'replacement_unit_code_snapshot' => ['character varying', true, 16],
            'request_note' => ['character varying', true, 300],
            'attention_at' => ['timestamp with time zone', false],
            'expires_at' => ['timestamp with time zone', false],
            'resolved_by_user_id' => ['uuid', true],
            'resolved_at' => ['timestamp with time zone', true],
            'resolution' => ['character varying', true, 16],
            'created_at' => ['timestamp with time zone', false],
            'updated_at' => ['timestamp with time zone', false],
        ]);

        $indexes = $this->indexesOn(self::TABLE);
        $this->assertStringContainsString('(order_id, status)', $indexes['customer_approvals_order_id_status_index']);
        $this->assertStringContainsString('(status, attention_at)', $indexes['customer_approvals_status_attention_at_index']);
        $this->assertStringContainsString('(status, expires_at)', $indexes['customer_approvals_status_expires_at_index']);
    }

    public function test_a_line_has_one_pending_approval_and_keeps_the_resolved_ones(): void
    {
        DB::table(self::TABLE)->insert($this->row(['status' => 'rejected', ...$this->resolvedBy($this->item->order->customer, 'rejected')]));
        DB::table(self::TABLE)->insert($this->row());

        $this->assertRejectedBy(
            self::TABLE,
            'customer_approvals_item_pending_unique',
            $this->row(),
            'BR-APP-011: at most one pending approval per line.'
        );
        $this->assertStringContainsString("WHERE ((status)::text = 'pending'::text)", $this->indexesOn(self::TABLE)['customer_approvals_item_pending_unique']);
    }

    public function test_every_type_and_status_the_wave_writes_is_accepted(): void
    {
        $customer = $this->item->order->customer;
        $operator = User::factory()->role(Role::Operator)->create();
        $others = OrderItem::factory()->for($this->item->order)->awaitingCustomer()->count(7)->create();

        $rows = [
            $this->row(['type' => 'substitution', ...$this->replacement()]),
            $this->row(['type' => 'reduced_quantity', 'proposed_quantity' => '1.500', 'proposed_customer_unit_price_uzs' => null, 'proposed_actual_market_price_uzs' => null]),
            // A price question about the authorized replacement names it (DL-54 (5)).
            $this->row([...$this->replacement(), 'request_note' => 'Подорожала']),
            $this->row(['status' => 'approved', ...$this->resolvedBy($customer, 'approved')]),
            $this->row(['status' => 'expired']),
            $this->row(['status' => 'expired', ...$this->resolvedBy($operator, 'remove_item')]),
            $this->row(['status' => 'cancelled', 'resolved_at' => now()]),
            $this->row(['status' => 'cancelled', 'resolved_by_user_id' => $operator->id, 'resolved_at' => now()]),
        ];

        foreach ($rows as $index => $row) {
            $line = $index === 0 ? $this->item : $others[$index - 1];
            DB::table(self::TABLE)->insert([...$row, 'order_item_id' => $line->id]);
        }

        $this->assertSame(8, DB::table(self::TABLE)->count());
    }

    public function test_a_proposal_has_the_shape_of_its_type(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'customer_approvals_proposal_check',
            $this->row(['proposed_customer_unit_price_uzs' => null]),
            'A price question proposes the price the Customer would pay.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'customer_approvals_proposal_check',
            $this->row(['proposed_quantity' => '1.000']),
            'A price question proposes no quantity.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'customer_approvals_proposal_check',
            $this->row(['type' => 'substitution']),
            'A substitution names its replacement.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'customer_approvals_proposal_check',
            $this->row(['type' => 'substitution', ...$this->replacement(), 'proposed_actual_market_price_uzs' => null]),
            'A replacement is priced from what the stall charges (docs/08 section 14).'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'customer_approvals_proposal_check',
            $this->row(['type' => 'reduced_quantity', 'proposed_quantity' => '1.000']),
            'A smaller quantity proposes no price.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'customer_approvals_proposal_check',
            $this->row(['type' => 'reduced_quantity', 'proposed_customer_unit_price_uzs' => null, 'proposed_actual_market_price_uzs' => null]),
            'A smaller quantity proposes the quantity.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'customer_approvals_proposed_values_check',
            $this->row(['type' => 'reduced_quantity', 'proposed_quantity' => '0', 'proposed_customer_unit_price_uzs' => null, 'proposed_actual_market_price_uzs' => null]),
            'docs/09 section 34: a positive quantity.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'customer_approvals_proposed_values_check',
            $this->row(['proposed_actual_market_price_uzs' => 0]),
            'A positive price.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'customer_approvals_replacement_check',
            $this->row(['replacement_product_id' => Product::factory()->create()->id]),
            'DL-3 S-24: a replacement comes with both names snapshotted.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'customer_approvals_replacement_check',
            $this->row([...$this->replacement(), 'replacement_unit_code_snapshot' => 'ton']),
            'BR-QTY-001.'
        );
    }

    public function test_each_status_carries_what_it_implies(): void
    {
        $customer = $this->item->order->customer;
        $operator = User::factory()->role(Role::Operator)->create();

        $this->assertRejectedBy(
            self::TABLE,
            'customer_approvals_cancelled_check',
            $this->row(['status' => 'cancelled']),
            'DL-54 (8): a cancelled approval says when.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'customer_approvals_cancelled_check',
            $this->row(['status' => 'cancelled', ...$this->resolvedBy($operator, 'remove_item')]),
            'Nobody decided a cancelled approval.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'customer_approvals_decided_check',
            $this->row(['status' => 'approved']),
            'BR-APP-005: the Customer decided, and when.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'customer_approvals_decided_check',
            $this->row(['status' => 'approved', ...$this->resolvedBy($customer, 'rejected')]),
            'The resolution is the decision.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'customer_approvals_expired_check',
            $this->row(['status' => 'expired', ...$this->resolvedBy($operator, 'approved')]),
            'BR-APP-007: an expired approval is resolved only by removing the line.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'customer_approvals_expired_check',
            $this->row(['status' => 'expired', 'resolution' => 'remove_item']),
            'The removal names the Operator and the instant.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'customer_approvals_pending_check',
            $this->row(['resolved_by_user_id' => $customer->id]),
            'Nobody resolved a pending approval.'
        );
    }

    public function test_the_line_belongs_to_the_approvals_order(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'customer_approvals_item_in_order_foreign',
            $this->row(['order_id' => Order::factory()->shopping()->create()->id]),
            'An approval is about a line of its own order.'
        );
    }

    public function test_the_proposal_is_immutable_and_a_resolution_final(): void
    {
        $customer = $this->item->order->customer;
        $pending = $this->row();
        DB::table(self::TABLE)->insert($pending);

        $this->assertRefusedChange(
            fn () => DB::table(self::TABLE)->where('id', $pending['id'])->update(['proposed_customer_unit_price_uzs' => 22000]),
            'a customer_approvals proposal is immutable',
            'BR-APP-001: the Customer decides on the proposal as it was made.'
        );
        $this->assertRefusedChange(
            fn () => DB::table(self::TABLE)->where('id', $pending['id'])->delete(),
            'customer_approvals are never deleted',
            'An approval is history.'
        );

        DB::table(self::TABLE)->where('id', $pending['id'])->update(['status' => 'approved', ...$this->resolvedBy($customer, 'approved')]);
        $this->assertRefusedChange(
            fn () => DB::table(self::TABLE)->where('id', $pending['id'])->update(['status' => 'rejected', 'resolution' => 'rejected']),
            'a resolved customer_approvals row never changes',
            'BR-APP-005: a decision is final.'
        );

        // An expired approval is resolved once more, by an Operator removing the line.
        $expired = $this->row(['status' => 'expired', 'order_item_id' => OrderItem::factory()->for($this->item->order)->awaitingCustomer()->create()->id]);
        DB::table(self::TABLE)->insert($expired);
        DB::table(self::TABLE)->where('id', $expired['id'])->update($this->resolvedBy(User::factory()->role(Role::Operator)->create(), 'remove_item'));
        $this->assertRefusedChange(
            fn () => DB::table(self::TABLE)->where('id', $expired['id'])->update(['resolved_at' => now()->addMinute()]),
            'a resolved customer_approvals row never changes',
            'BR-APP-007: the removal is final.'
        );

        $this->assertSame('approved', DB::table(self::TABLE)->where('id', $pending['id'])->value('status'));
        $this->assertSame('remove_item', DB::table(self::TABLE)->where('id', $expired['id'])->value('resolution'));
    }

    public function test_the_vocabularies_the_timers_and_the_note_are_enforced(): void
    {
        $this->assertRejectedBy(self::TABLE, 'customer_approvals_note_check', $this->row(['request_note' => ' ']), 'A note says something.');
        // Every status constrains its resolution, so only a row whose status is
        // itself unknown reaches the vocabulary of resolutions.
        $this->assertRejectedBy(
            self::TABLE,
            'customer_approvals_resolution_check',
            $this->row(['status' => 'waiting', 'resolution' => 'maybe']),
            '08 Section 18.'
        );
        $this->assertRejectedBy(self::TABLE, 'customer_approvals_status_check', $this->row(['status' => 'waiting']), 'DL-54 (8).');
        $at = now()->addMinutes(30);
        $this->assertRejectedBy(
            self::TABLE,
            'customer_approvals_timers_check',
            $this->row(['attention_at' => $at, 'expires_at' => $at]),
            'BR-APP-002, BR-APP-003: attention comes before expiry.'
        );
        $this->assertRejectedBy(self::TABLE, 'customer_approvals_type_check', $this->row(['type' => 'discount']), 'Three kinds of question.');
    }

    private function assertRefusedChange(callable $change, string $refusal, string $why): void
    {
        DB::beginTransaction();

        try {
            $change();
            $this->fail("PostgreSQL accepted the change. {$why}");
        } catch (QueryException $exception) {
            $this->assertStringContainsString($refusal, $exception->getMessage(), $why);
        } finally {
            DB::rollBack();
        }
    }
}
