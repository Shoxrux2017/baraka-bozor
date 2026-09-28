<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\Support\Database\RollsBackMigrations;
use Tests\TestCase;

/**
 * What the Wave 3 migrations promise as a set: they roll back and run again —
 * the new tables, the history's Wave 3 events and the shopping rules on
 * `order_items` with them — every foreign key is `RESTRICT`, and every numeric
 * column has the precision `docs/08-database.md` section 1 fixes.
 */
final class Wave3MigrationsTest extends TestCase
{
    use RefreshDatabase;
    use RollsBackMigrations;

    private const FIRST = '2026_09_28_000001_create_order_courier_assignments_table';

    /** The event list the Wave 2 migration created, which a rollback restores exactly. */
    private const WAVE_2_EVENTS = "CHECK (((event_type)::text = ANY ((ARRAY['status_changed'::character varying, 'edited'::character varying, 'payment_method_switched'::character varying, 'price_corrected'::character varying, 'shopper_assigned'::character varying, 'shopper_reassigned'::character varying, 'courier_assigned'::character varying, 'courier_reassigned'::character varying, 'delivery_failed'::character varying, 'approval_requested'::character varying, 'approval_decided'::character varying, 'approval_expired'::character varying, 'approval_resolved'::character varying])::text[])))";

    private const TABLES = [
        'order_courier_assignments',
        'customer_approvals',
        'order_cancellation_requests',
        'order_item_price_corrections',
        'payments',
    ];

    public function test_the_migrations_roll_back_in_reverse_order_and_run_again(): void
    {
        $rolledBack = $this->rollBackFrom(self::FIRST);

        foreach (self::TABLES as $table) {
            $this->assertFalse(Schema::hasTable($table), "{$table} survived its rollback.");
        }
        $this->assertFalse(Schema::hasColumn('order_items', 'approved_replacement_price_uzs'));
        $this->assertSame(self::WAVE_2_EVENTS, $this->eventCheck());
        $this->assertFalse($this->functionExists('order_item_price_corrections_append_only'), 'The corrections\' append-only function survived its table.');
        $this->assertFalse($this->functionExists('customer_approvals_guard'), 'The approvals\' guard survived its table.');
        $this->assertFalse($this->indexExists('order_items_id_order_id_unique'), 'The line-in-order key survived the approvals.');
        $this->assertTrue(Schema::hasTable('orders'), 'A Wave 3 rollback must not reach the Wave 2 tables.');

        $this->runAgain($rolledBack);

        foreach (self::TABLES as $table) {
            $this->assertTrue(Schema::hasTable($table), "{$table} was not recreated.");
        }
        $this->assertTrue(Schema::hasColumn('order_items', 'approved_replacement_price_uzs'));
        $this->assertStringContainsString("'payment_recorded'", $this->eventCheck());
        $this->assertTrue($this->functionExists('order_item_price_corrections_append_only'));
        $this->assertTrue($this->functionExists('customer_approvals_guard'));
        $this->assertTrue($this->indexExists('order_items_id_order_id_unique'));
    }

    public function test_every_wave_3_foreign_key_is_restrict(): void
    {
        $keys = DB::select(
            "select conname, confdeltype from pg_constraint
              where contype = 'f' and conrelid::regclass::text = any (?)
              order by conname",
            ['{'.implode(',', self::TABLES).'}']
        );

        $byName = [];
        foreach ($keys as $key) {
            $byName[(string) $key->conname] = (string) $key->confdeltype;
        }

        $this->assertSame([
            'customer_approvals_item_in_order_foreign' => 'r',
            'customer_approvals_order_id_foreign' => 'r',
            'customer_approvals_order_item_id_foreign' => 'r',
            'customer_approvals_replacement_product_id_foreign' => 'r',
            'customer_approvals_requested_by_user_id_foreign' => 'r',
            'customer_approvals_resolved_by_user_id_foreign' => 'r',
            'order_cancellation_requests_order_id_foreign' => 'r',
            'order_cancellation_requests_requested_by_user_id_foreign' => 'r',
            'order_cancellation_requests_resolved_by_user_id_foreign' => 'r',
            'order_courier_assignments_assigned_by_user_id_foreign' => 'r',
            'order_courier_assignments_courier_id_foreign' => 'r',
            'order_courier_assignments_order_id_foreign' => 'r',
            'order_item_price_corrections_corrected_by_user_id_foreign' => 'r',
            'order_item_price_corrections_order_item_id_foreign' => 'r',
            'payments_order_id_foreign' => 'r',
            'payments_recorded_by_user_id_foreign' => 'r',
        ], $byName, 'docs/08 section 28: RESTRICT on every business-history foreign key.');
    }

    public function test_every_numeric_column_has_the_documented_precision_and_scale(): void
    {
        $rows = DB::select(
            "select table_name || '.' || column_name as name, numeric_precision, numeric_scale
               from information_schema.columns
              where table_schema = current_schema() and data_type = 'numeric' and table_name = any (?)
              order by name",
            ['{'.implode(',', self::TABLES).'}']
        );

        $actual = [];
        foreach ($rows as $row) {
            $actual[(string) $row->name] = [(int) $row->numeric_precision, (int) $row->numeric_scale];
        }

        $this->assertSame(['customer_approvals.proposed_quantity' => [18, 3]], $actual);
    }

    private function eventCheck(): string
    {
        return (string) DB::selectOne(
            "select pg_get_constraintdef(oid) as definition from pg_constraint where conname = 'order_history_event_type_check'"
        )->definition;
    }

    private function functionExists(string $name): bool
    {
        return DB::selectOne('select exists (select 1 from pg_proc where proname = ?) as present', [$name])->present;
    }

    private function indexExists(string $name): bool
    {
        return DB::selectOne('select to_regclass(?) is not null as present', [$name])->present;
    }
}
