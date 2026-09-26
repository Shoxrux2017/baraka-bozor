<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\Database\AssertsDatabaseRejections;
use Tests\Support\Database\ReadsPostgresCatalog;
use Tests\TestCase;

/**
 * `payment_provider_settings`, as `docs/08-database.md` Section 12 names it:
 * the four providers of `DL-2` 3.3, present from the migration and disabled.
 */
final class PaymentProviderSettingsTableTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    private const TABLE = 'payment_provider_settings';

    public function test_it_has_exactly_the_columns_the_schema_names_and_no_secret(): void
    {
        $columns = array_keys($this->columnsOf(self::TABLE));
        sort($columns);

        $this->assertSame(
            ['created_at', 'is_enabled', 'provider', 'updated_at', 'updated_by_user_id'],
            $columns,
            'The table holds enablement only; credentials are backend configuration (08 Section 12).'
        );
    }

    public function test_the_four_providers_exist_and_are_disabled(): void
    {
        $rows = DB::table(self::TABLE)->orderBy('provider')->get();

        $this->assertSame(['click', 'payme', 'paynet', 'xazna'], $rows->pluck('provider')->all());
        $this->assertSame([false, false, false, false], $rows->map(fn (object $row): bool => (bool) $row->is_enabled)->all());
    }

    public function test_a_provider_outside_the_four_is_rejected(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'payment_provider_settings_provider_check',
            ['provider' => 'stripe', 'is_enabled' => false, 'created_at' => now(), 'updated_at' => now()],
            'A fifth provider is a product decision and an adapter, not a row.'
        );
    }

    public function test_a_provider_appears_once(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'payment_provider_settings_pkey',
            ['provider' => 'payme', 'is_enabled' => true, 'created_at' => now(), 'updated_at' => now()],
            'The provider is the key; enabling one is an update.'
        );
    }
}
