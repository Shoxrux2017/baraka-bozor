<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use App\Models\Order;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\Database\AssertsDatabaseRejections;
use Tests\Support\Database\ReadsPostgresCatalog;
use Tests\TestCase;

/**
 * `orders`, as `docs/08-database.md` Section 13 names it, with the sequence of
 * `DL-37` (2) and the checks of `DL-38` that hold what each status implies.
 *
 * Each check is proven by a row only it refuses. PostgreSQL evaluates checks
 * in name order, so a row meant for one check satisfies every check named
 * before it.
 */
final class OrdersTableTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    private const TABLE = 'orders';

    /** The final amounts of a shopped order: 100 000 + 5 000 + 15 000. */
    private const SHOPPED = [
        'shopping_started_at' => '2026-09-27 08:00:00+00',
        'shopping_completed_at' => '2026-09-27 09:00:00+00',
        'final_merchandise_subtotal_uzs' => 100000,
        'final_service_fee_uzs' => 5000,
        'final_total_uzs' => 120000,
    ];

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function row(array $overrides = []): array
    {
        return array_merge(
            Order::factory()->raw(),
            ['id' => (string) Str::uuid(), 'created_at' => now(), 'updated_at' => now()],
            $overrides
        );
    }

    public function test_it_has_exactly_the_columns_the_schema_names_with_their_types_and_lengths(): void
    {
        $this->assertColumns(self::TABLE, [
            'id' => ['uuid', false],
            'order_number' => ['bigint', false],
            'customer_id' => ['uuid', false],
            'source_cart_id' => ['uuid', false],
            'source_address_id' => ['uuid', false],
            'status' => ['character varying', false, 32],
            'payment_method' => ['character varying', false, 16],
            'delivery_time_note' => ['character varying', true, 160],
            'recipient_name_snapshot' => ['character varying', false, 160],
            'recipient_phone_snapshot' => ['character varying', false, 20],
            'latitude_snapshot' => ['numeric', false],
            'longitude_snapshot' => ['numeric', false],
            'street_snapshot' => ['character varying', false, 160],
            'house_snapshot' => ['character varying', false, 40],
            'apartment_snapshot' => ['character varying', true, 40],
            'landmark_snapshot' => ['character varying', true, 160],
            'delivery_note_snapshot' => ['character varying', true, 300],
            'markup_percent_snapshot' => ['numeric', false],
            'price_tolerance_percent_snapshot' => ['numeric', false],
            'service_fee_mode_snapshot' => ['character varying', false, 16],
            'service_fee_fixed_uzs_snapshot' => ['bigint', true],
            'service_fee_percent_snapshot' => ['numeric', true],
            'delivery_fee_uzs_snapshot' => ['bigint', false],
            'delivery_delay_threshold_minutes_snapshot' => ['integer', false],
            'final_merchandise_subtotal_uzs' => ['bigint', true],
            'final_service_fee_uzs' => ['bigint', true],
            'final_total_uzs' => ['bigint', true],
            'shopping_started_at' => ['timestamp with time zone', true],
            'shopping_completed_at' => ['timestamp with time zone', true],
            'ready_for_delivery_at' => ['timestamp with time zone', true],
            'on_the_way_at' => ['timestamp with time zone', true],
            'completed_at' => ['timestamp with time zone', true],
            'cancelled_at' => ['timestamp with time zone', true],
            'cancellation_reason_code' => ['character varying', true, 40],
            'created_at' => ['timestamp with time zone', false],
            'updated_at' => ['timestamp with time zone', false],
        ]);
    }

    public function test_order_numbers_come_from_the_sequence_starting_at_1001_and_are_unique(): void
    {
        // A sequence does not roll back with the test's transaction, so the
        // numbers depend on the tests before; its start and the step do not.
        $sequence = DB::selectOne(
            "select start_value, increment_by from pg_sequences where sequencename = 'orders_order_number_seq'"
        );
        $this->assertSame(1001, (int) $sequence->start_value);
        $this->assertSame(1, (int) $sequence->increment_by);

        DB::table(self::TABLE)->insert($this->row());
        DB::table(self::TABLE)->insert($this->row());

        $numbers = DB::table(self::TABLE)->orderBy('order_number')->pluck('order_number')->map(
            static fn (mixed $number): int => (int) $number
        )->all();
        $this->assertGreaterThanOrEqual(1001, $numbers[0]);
        $this->assertSame($numbers[0] + 1, $numbers[1]);

        $this->assertRejectedBy(
            self::TABLE,
            'orders_order_number_unique',
            $this->row(['order_number' => $numbers[0]]),
            'BR-ORDER-005: an order number is never shared.'
        );
    }

    public function test_one_cart_makes_at_most_one_order(): void
    {
        $first = $this->row();
        DB::table(self::TABLE)->insert($first);

        $this->assertRejectedBy(
            self::TABLE,
            'orders_source_cart_id_unique',
            $this->row(['source_cart_id' => $first['source_cart_id']]),
            'A cart is converted into exactly one order (BR-CHK-008).'
        );
    }

    public function test_the_vocabularies_are_enforced(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'orders_status_check',
            $this->row(['status' => 'approval_required', 'shopping_started_at' => now()]),
            'DL-3 S-6: derived, not stored.'
        );
        $this->assertRejectedBy(self::TABLE, 'orders_payment_method_check', $this->row(['payment_method' => 'card']), 'Cash or online only.');
        $this->assertRejectedBy(self::TABLE, 'orders_service_fee_mode_check', $this->row(['service_fee_mode_snapshot' => 'monthly']), 'Fixed or percentage.');
        $this->assertRejectedBy(
            self::TABLE,
            'orders_cancellation_reason_check',
            $this->row(['status' => 'cancelled', 'cancelled_at' => now(), 'cancellation_reason_code' => 'changed_mind']),
            'DL-3 S-9 fixes the cancellation reasons.'
        );
    }

    public function test_the_service_fee_snapshot_carries_the_value_of_its_mode_only(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'orders_service_fee_value_by_mode_check',
            $this->row(['service_fee_percent_snapshot' => '3.00']),
            'A fixed fee snapshot carries no percentage.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'orders_service_fee_value_by_mode_check',
            $this->row(['service_fee_mode_snapshot' => 'percentage']),
            'A percentage snapshot needs its percentage and no fixed amount.'
        );
    }

    public function test_the_snapshots_are_held_to_their_shapes(): void
    {
        $this->assertRejectedBy(self::TABLE, 'orders_recipient_phone_format_check', $this->row(['recipient_phone_snapshot' => '901234567']), '+998 and nine digits.');
        $this->assertRejectedBy(self::TABLE, 'orders_recipient_name_not_blank_check', $this->row(['recipient_name_snapshot' => ' ']), 'BR-CHK-001: a name.');
        $this->assertRejectedBy(self::TABLE, 'orders_street_not_blank_check', $this->row(['street_snapshot' => ' ']), 'BR-CHK-002.');
        $this->assertRejectedBy(self::TABLE, 'orders_house_not_blank_check', $this->row(['house_snapshot' => '']), 'BR-CHK-002.');
        $this->assertRejectedBy(self::TABLE, 'orders_latitude_range_check', $this->row(['latitude_snapshot' => '91']), 'A real point.');
        $this->assertRejectedBy(self::TABLE, 'orders_longitude_range_check', $this->row(['longitude_snapshot' => '181']), 'A real point.');
        $this->assertRejectedBy(self::TABLE, 'orders_amounts_not_negative_check', $this->row(['delivery_fee_uzs_snapshot' => -1]), 'No negative fee.');
        $this->assertRejectedBy(self::TABLE, 'orders_amounts_not_negative_check', $this->row(['markup_percent_snapshot' => '-1']), 'No negative markup.');
        $this->assertRejectedBy(self::TABLE, 'orders_delay_threshold_check', $this->row(['delivery_delay_threshold_minutes_snapshot' => 0]), 'A positive threshold.');
    }

    public function test_the_final_amounts_come_all_together_are_not_negative_and_add_up(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'orders_final_amounts_check',
            $this->row(['final_total_uzs' => 120000]),
            'BR-MONEY-006: all three amounts or none.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'orders_final_amounts_check',
            $this->row(array_merge(self::SHOPPED, ['final_total_uzs' => 119999])),
            'BR-MONEY-006: the total is the subtotal plus the service fee plus the delivery fee.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'orders_final_amounts_check',
            $this->row(array_merge(self::SHOPPED, ['final_merchandise_subtotal_uzs' => -1000, 'final_total_uzs' => 19000])),
            'BR-MONEY-004: a subtotal is never negative.'
        );
    }

    public function test_the_stored_service_fee_follows_the_snapshotted_rule(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'orders_final_service_fee_check',
            $this->row(array_merge(self::SHOPPED, ['final_service_fee_uzs' => 4000, 'final_total_uzs' => 119000])),
            'BR-MONEY-005: a fixed fee is the snapshotted amount.'
        );

        $percentage = [
            'service_fee_mode_snapshot' => 'percentage',
            'service_fee_fixed_uzs_snapshot' => null,
            'service_fee_percent_snapshot' => '3.00',
            'final_merchandise_subtotal_uzs' => 100050,
        ];
        // 3 % of 100 050 is 3 001.5: half-up to 3 002.
        $this->assertRejectedBy(
            self::TABLE,
            'orders_final_service_fee_check',
            $this->row(array_merge(self::SHOPPED, $percentage, ['final_service_fee_uzs' => 3001, 'final_total_uzs' => 118051])),
            'BR-MONEY-005: half-up, not down.'
        );
        DB::table(self::TABLE)->insert($this->row(array_merge(self::SHOPPED, $percentage, [
            'final_service_fee_uzs' => 3002,
            'final_total_uzs' => 118052,
        ])));
        $this->assertSame(1, DB::table(self::TABLE)->count());
    }

    public function test_each_status_carries_what_it_implies(): void
    {
        $this->assertRejectedBy(self::TABLE, 'orders_shopping_started_check', $this->row(['status' => 'shopping']), 'Shopping has a start.');
        $this->assertRejectedBy(
            self::TABLE,
            'orders_after_shopping_state_check',
            $this->row(['status' => 'ready_for_delivery', 'ready_for_delivery_at' => now(), 'shopping_started_at' => now()]),
            'After shopping, the final amounts exist.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'orders_after_shopping_state_check',
            $this->row(array_merge(self::SHOPPED, ['status' => 'ready_for_delivery', 'ready_for_delivery_at' => now(), 'shopping_completed_at' => null])),
            'After shopping, its completion is recorded.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'orders_ready_for_delivery_check',
            $this->row(array_merge(self::SHOPPED, ['status' => 'delivery_assigned'])),
            'A delivery follows readiness.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'orders_on_the_way_check',
            $this->row(array_merge(self::SHOPPED, ['status' => 'on_the_way', 'ready_for_delivery_at' => now()])),
            'On the way has its instant.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'orders_completed_check',
            $this->row(['completed_at' => now()]),
            'Only a completed order has completed_at.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'orders_completed_check',
            $this->row(array_merge(self::SHOPPED, ['status' => 'completed', 'ready_for_delivery_at' => now(), 'on_the_way_at' => now()])),
            'A completed order has completed_at.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'orders_cancelled_check',
            $this->row(['status' => 'cancelled', 'cancelled_at' => now()]),
            'A cancelled order records why (BR-CAN-005).'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'orders_cancelled_check',
            $this->row(['status' => 'cancelled', 'cancellation_reason_code' => 'system']),
            'A cancelled order records when.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'orders_cancelled_check',
            $this->row(['cancellation_reason_code' => 'system']),
            'Only a cancelled order has a cancellation reason.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'orders_cancelled_check',
            $this->row(['cancelled_at' => now()]),
            'Only a cancelled order has cancelled_at.'
        );
    }

    public function test_a_cancelled_order_may_keep_the_amounts_it_reached(): void
    {
        DB::table(self::TABLE)->insert($this->row(array_merge(self::SHOPPED, [
            'status' => 'cancelled',
            'payment_method' => 'online',
            'cancelled_at' => now(),
            'cancellation_reason_code' => 'unpaid_online',
        ])));

        $this->assertSame(1, DB::table(self::TABLE)->count());
    }

    public function test_it_indexes_the_board_and_the_customers_history(): void
    {
        $indexes = $this->indexesOn(self::TABLE);

        $this->assertStringContainsString('(customer_id, created_at)', $indexes['orders_customer_id_created_at_index']);
        $this->assertStringContainsString('(status, created_at)', $indexes['orders_status_created_at_index']);
        $this->assertStringContainsString('(status, updated_at)', $indexes['orders_status_updated_at_index']);
        $this->assertArrayHasKey('orders_completed_at_index', $indexes);
        $this->assertArrayHasKey('orders_cancelled_at_index', $indexes);
    }
}
