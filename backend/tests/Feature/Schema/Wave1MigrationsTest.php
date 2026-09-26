<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

/**
 * What the Wave 1 migrations promise as a set: they roll back and run again,
 * every foreign key is `RESTRICT` rather than merely refusing, and every
 * numeric column has the precision `docs/08-database.md` section 1 fixes.
 *
 * The rollback runs inside the test's transaction; PostgreSQL DDL is
 * transactional, so the database is back as it was when the test ends.
 */
final class Wave1MigrationsTest extends TestCase
{
    use RefreshDatabase;

    /** In creation order; rolled back in reverse. */
    private const MIGRATIONS = [
        '2026_09_26_000001_create_customer_addresses_table' => 'customer_addresses',
        '2026_09_26_000002_create_categories_table' => 'categories',
        '2026_09_26_000003_create_products_table' => 'products',
        '2026_09_26_000004_create_product_images_table' => 'product_images',
        '2026_09_26_000005_create_business_settings_table' => 'business_settings',
        '2026_09_26_000006_create_payment_provider_settings_table' => 'payment_provider_settings',
        '2026_09_26_000007_create_push_devices_table' => 'push_devices',
    ];

    public function test_the_migrations_roll_back_in_reverse_order_and_run_again(): void
    {
        foreach (array_reverse(self::MIGRATIONS, true) as $file => $table) {
            $this->runMigration($file, 'down');
            $this->assertFalse(Schema::hasTable($table), "{$table} survived its rollback.");
        }

        $this->assertTrue(Schema::hasTable('users'), 'A Wave 1 rollback must not reach the Wave 0 tables.');

        foreach (self::MIGRATIONS as $file => $table) {
            $this->runMigration($file, 'up');
            $this->assertTrue(Schema::hasTable($table), "{$table} was not recreated.");
        }

        $this->assertSame(1, DB::table('business_settings')->count());
        $this->assertSame(4, DB::table('payment_provider_settings')->count());
    }

    public function test_every_wave_1_foreign_key_is_restrict(): void
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
            'business_settings_updated_by_user_id_foreign' => 'r',
            'categories_created_by_user_id_foreign' => 'r',
            'customer_addresses_customer_id_foreign' => 'r',
            'payment_provider_settings_updated_by_user_id_foreign' => 'r',
            'product_images_product_id_foreign' => 'r',
            'products_category_id_foreign' => 'r',
            'products_created_by_user_id_foreign' => 'r',
            'push_devices_user_id_foreign' => 'r',
        ], $byName, 'docs/08 section 28: RESTRICT on every business-history foreign key.');
    }

    public function test_every_numeric_column_has_the_documented_precision_and_scale(): void
    {
        $expected = [
            'business_settings.markup_percent' => [5, 2],
            'business_settings.price_tolerance_percent' => [5, 2],
            'business_settings.service_centre_latitude' => [9, 6],
            'business_settings.service_centre_longitude' => [10, 6],
            'business_settings.service_fee_percent' => [5, 2],
            'business_settings.service_radius_km' => [6, 2],
            'customer_addresses.latitude' => [9, 6],
            'customer_addresses.longitude' => [10, 6],
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

    /**
     * Runs one direction of one migration file. The file returns an anonymous
     * class, so the method is called by name.
     */
    private function runMigration(string $file, string $direction): void
    {
        $migration = require database_path("migrations/{$file}.php");

        $migration->{$direction}();
    }
}
