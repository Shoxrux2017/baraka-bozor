<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Feature\Identity\AssertsDatabaseRejections;
use Tests\Feature\Identity\ReadsPostgresCatalog;
use Tests\TestCase;

/**
 * `business_settings`, as `docs/08-database.md` Section 11 names it: one row
 * that exists from the migration, with the documented defaults and nulls for
 * what Admin has yet to configure.
 */
final class BusinessSettingsTableTest extends TestCase
{
    use AssertsDatabaseRejections;
    use AssertsUpdateRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    private const TABLE = 'business_settings';

    /** @var array<string, int> */
    private const SINGLETON = ['id' => 1];

    /**
     * @return array<string, array{string, bool}>
     */
    private function expectedColumns(): array
    {
        return [
            'id' => ['smallint', false],
            'markup_percent' => ['numeric', false],
            'service_fee_mode' => ['character varying', false],
            'service_fee_fixed_uzs' => ['bigint', true],
            'service_fee_percent' => ['numeric', true],
            'delivery_fee_uzs' => ['bigint', true],
            'minimum_order_uzs' => ['bigint', true],
            'price_tolerance_percent' => ['numeric', false],
            'opens_at' => ['time without time zone', true],
            'closes_at' => ['time without time zone', true],
            'service_centre_latitude' => ['numeric', true],
            'service_centre_longitude' => ['numeric', true],
            'service_radius_km' => ['numeric', true],
            'delivery_delay_threshold_minutes' => ['integer', false],
            'updated_by_user_id' => ['uuid', true],
            'created_at' => ['timestamp with time zone', false],
            'updated_at' => ['timestamp with time zone', false],
        ];
    }

    public function test_it_has_exactly_the_columns_the_schema_names_with_their_types(): void
    {
        $actual = $this->columnsOf(self::TABLE);
        $expected = $this->expectedColumns();

        $names = array_keys($actual);
        $expectedNames = array_keys($expected);
        sort($names);
        sort($expectedNames);
        $this->assertSame($expectedNames, $names);

        foreach ($expected as $column => [$type, $nullable]) {
            $this->assertSame($type, $actual[$column]->data_type, self::TABLE.".{$column} type");
            $this->assertSame($nullable ? 'YES' : 'NO', $actual[$column]->is_nullable, self::TABLE.".{$column} nullability");
        }
    }

    public function test_the_singleton_row_exists_with_the_documented_defaults_and_nothing_configured(): void
    {
        $rows = DB::table(self::TABLE)->get();

        $this->assertCount(1, $rows);
        $row = $rows->first();
        $this->assertSame(1, (int) $row->id);
        $this->assertSame('0.00', (string) $row->markup_percent);
        $this->assertSame('fixed', $row->service_fee_mode);
        $this->assertSame('15.00', (string) $row->price_tolerance_percent);
        $this->assertSame(60, (int) $row->delivery_delay_threshold_minutes);

        foreach ([
            'service_fee_fixed_uzs', 'service_fee_percent', 'delivery_fee_uzs', 'minimum_order_uzs',
            'opens_at', 'closes_at', 'service_centre_latitude', 'service_centre_longitude',
            'service_radius_km', 'updated_by_user_id',
        ] as $unset) {
            $this->assertNull($row->{$unset}, "{$unset} starts unset until Admin configures it (BR-SET-002).");
        }
    }

    public function test_a_second_row_is_rejected(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'business_settings_singleton_check',
            ['id' => 2, 'created_at' => now(), 'updated_at' => now()],
            'There is one business (BR-CORE-002); a second settings row would be read by nobody.'
        );
    }

    public function test_the_service_fee_value_of_the_inactive_mode_must_stay_null(): void
    {
        $this->assertUpdateRejectedBy(
            self::TABLE,
            'business_settings_service_fee_value_by_mode_check',
            self::SINGLETON,
            ['service_fee_mode' => 'fixed', 'service_fee_percent' => '5.00'],
            'A percentage stored while the mode is fixed is a stale value waiting to be misread.'
        );
        $this->assertUpdateRejectedBy(
            self::TABLE,
            'business_settings_service_fee_value_by_mode_check',
            self::SINGLETON,
            ['service_fee_mode' => 'percentage', 'service_fee_fixed_uzs' => 10000],
            'A fixed amount stored while the mode is percentage is the same stale value.'
        );

        // Both consistent shapes are accepted.
        DB::table(self::TABLE)->where(self::SINGLETON)->update(['service_fee_mode' => 'percentage', 'service_fee_percent' => '5.00']);
        DB::table(self::TABLE)->where(self::SINGLETON)->update(['service_fee_mode' => 'fixed', 'service_fee_percent' => null, 'service_fee_fixed_uzs' => 10000]);
        $this->assertSame(10000, (int) DB::table(self::TABLE)->value('service_fee_fixed_uzs'));
    }

    public function test_negative_amounts_and_percentages_are_rejected(): void
    {
        foreach ([
            ['business_settings_markup_percent_check', ['markup_percent' => '-1.00']],
            ['business_settings_service_fee_fixed_check', ['service_fee_fixed_uzs' => -1]],
            ['business_settings_delivery_fee_check', ['delivery_fee_uzs' => -1]],
            ['business_settings_minimum_order_check', ['minimum_order_uzs' => -1]],
            ['business_settings_price_tolerance_check', ['price_tolerance_percent' => '-0.01']],
            ['business_settings_service_radius_check', ['service_radius_km' => '0.00']],
            ['business_settings_delay_threshold_check', ['delivery_delay_threshold_minutes' => 0]],
        ] as [$constraint, $values]) {
            $this->assertUpdateRejectedBy(self::TABLE, $constraint, self::SINGLETON, $values, 'BR-SET-001 values are non-negative, and a radius or threshold of zero disables the rule it exists for.');
        }
    }

    public function test_working_hours_come_as_a_pair_and_the_centre_lies_on_earth(): void
    {
        $this->assertUpdateRejectedBy(
            self::TABLE,
            'business_settings_working_hours_pair_check',
            self::SINGLETON,
            ['opens_at' => '08:00'],
            'An opening time without a closing time is not working hours.'
        );
        $this->assertUpdateRejectedBy(
            self::TABLE,
            'business_settings_service_centre_latitude_check',
            self::SINGLETON,
            ['service_centre_latitude' => '95.000000'],
            'A centre off the planet would refuse every address.'
        );
        $this->assertUpdateRejectedBy(
            self::TABLE,
            'business_settings_service_centre_longitude_check',
            self::SINGLETON,
            ['service_centre_longitude' => '181.000000'],
            'A centre off the planet would refuse every address.'
        );

        DB::table(self::TABLE)->where(self::SINGLETON)->update(['opens_at' => '08:00', 'closes_at' => '20:00']);
        $this->assertSame('08:00:00', (string) DB::table(self::TABLE)->value('opens_at'));
    }
}
