<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\Support\Database\RollsBackMigrations;
use Tests\TestCase;

/**
 * What the Wave 2 migrations promise as a set: they roll back and run again,
 * the order number sequence goes with its table, every foreign key is
 * `RESTRICT`, and every numeric column has the precision `docs/08-database.md`
 * section 1 fixes.
 */
final class Wave2MigrationsTest extends TestCase
{
    use RefreshDatabase;
    use RollsBackMigrations;

    /** In creation order; rolled back in reverse. */
    private const MIGRATIONS = [
        '2026_09_27_000001_create_carts_table' => 'carts',
        '2026_09_27_000002_create_cart_items_table' => 'cart_items',
        '2026_09_27_000003_create_orders_table' => 'orders',
        '2026_09_27_000004_create_order_items_table' => 'order_items',
        '2026_09_27_000005_create_order_history_table' => 'order_history',
        '2026_09_27_000006_create_order_shopper_assignments_table' => 'order_shopper_assignments',
        '2026_09_27_000007_create_idempotency_keys_table' => 'idempotency_keys',
    ];

    public function test_the_migrations_roll_back_in_reverse_order_and_run_again(): void
    {
        $rolledBack = $this->rollBackFrom(array_key_first(self::MIGRATIONS));

        foreach (self::MIGRATIONS as $table) {
            $this->assertFalse(Schema::hasTable($table), "{$table} survived its rollback.");
        }

        $this->assertFalse($this->sequenceExists(), 'The order number sequence survived its table.');
        $this->assertFalse($this->functionExists(), 'The append-only trigger function survived its table.');
        $this->assertTrue(Schema::hasTable('products'), 'A Wave 2 rollback must not reach the Wave 1 tables.');

        $this->runAgain($rolledBack);

        foreach (self::MIGRATIONS as $table) {
            $this->assertTrue(Schema::hasTable($table), "{$table} was not recreated.");
        }

        $this->assertTrue($this->sequenceExists());
        $this->assertTrue($this->functionExists());
    }

    public function test_every_wave_2_foreign_key_is_restrict(): void
    {
        $keys = DB::select(
            "select conname, confdeltype from pg_constraint
              where contype = 'f' and conrelid::regclass::text = any (?)
              order by conname",
            ['{'.implode(',', self::MIGRATIONS).'}']
        );

        $byName = [];
        foreach ($keys as $key) {
            $byName[(string) $key->conname] = (string) $key->confdeltype;
        }

        $this->assertSame([
            'cart_items_cart_id_foreign' => 'r',
            'cart_items_product_id_foreign' => 'r',
            'carts_customer_id_foreign' => 'r',
            'idempotency_keys_actor_user_id_foreign' => 'r',
            'order_history_actor_user_id_foreign' => 'r',
            'order_history_order_id_foreign' => 'r',
            'order_items_fulfilled_product_id_foreign' => 'r',
            'order_items_order_id_foreign' => 'r',
            'order_items_product_id_foreign' => 'r',
            'order_shopper_assignments_assigned_by_user_id_foreign' => 'r',
            'order_shopper_assignments_order_id_foreign' => 'r',
            'order_shopper_assignments_shopper_id_foreign' => 'r',
            'orders_customer_id_foreign' => 'r',
            'orders_source_address_id_foreign' => 'r',
            'orders_source_cart_id_foreign' => 'r',
        ], $byName, 'docs/08 section 28: RESTRICT on every business-history foreign key.');
    }

    public function test_every_numeric_column_has_the_documented_precision_and_scale(): void
    {
        $expected = [
            'cart_items.quantity' => [18, 3],
            'order_items.approved_quantity_cap' => [18, 3],
            'order_items.billable_quantity' => [18, 3],
            'order_items.markup_percent_snapshot' => [5, 2],
            'order_items.ordered_quantity' => [18, 3],
            'order_items.purchased_quantity' => [18, 3],
            'orders.latitude_snapshot' => [9, 6],
            'orders.longitude_snapshot' => [10, 6],
            'orders.markup_percent_snapshot' => [5, 2],
            'orders.price_tolerance_percent_snapshot' => [5, 2],
            'orders.service_fee_percent_snapshot' => [5, 2],
        ];

        $rows = DB::select(
            "select table_name || '.' || column_name as name, numeric_precision, numeric_scale
               from information_schema.columns
              where table_schema = current_schema() and data_type = 'numeric' and table_name = any (?)
              order by name",
            ['{'.implode(',', self::MIGRATIONS).'}']
        );

        $actual = [];
        foreach ($rows as $row) {
            $actual[(string) $row->name] = [(int) $row->numeric_precision, (int) $row->numeric_scale];
        }

        $this->assertSame($expected, $actual);
    }

    private function sequenceExists(): bool
    {
        return DB::selectOne("select to_regclass('orders_order_number_seq') is not null as present")->present;
    }

    private function functionExists(): bool
    {
        return DB::selectOne("select exists (select 1 from pg_proc where proname = 'order_history_append_only') as present")->present;
    }
}
