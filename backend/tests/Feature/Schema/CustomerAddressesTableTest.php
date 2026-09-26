<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\Database\AssertsDatabaseRejections;
use Tests\Support\Database\ReadsPostgresCatalog;
use Tests\TestCase;

/**
 * `customer_addresses`, as `docs/08-database.md` Section 5 names it.
 */
final class CustomerAddressesTableTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    private const TABLE = 'customer_addresses';

    /**
     * @return array<string, array{string, bool}>
     */
    private function expectedColumns(): array
    {
        return [
            'id' => ['uuid', false],
            'customer_id' => ['uuid', false],
            'label' => ['character varying', true],
            'latitude' => ['numeric', false],
            'longitude' => ['numeric', false],
            'street' => ['character varying', false],
            'house' => ['character varying', false],
            'apartment' => ['character varying', true],
            'landmark' => ['character varying', true],
            'delivery_note' => ['character varying', true],
            'is_active' => ['boolean', false],
            'created_at' => ['timestamp with time zone', false],
            'updated_at' => ['timestamp with time zone', false],
        ];
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function row(array $overrides = []): array
    {
        return array_merge([
            'id' => (string) Str::uuid(),
            'customer_id' => User::factory()->customer()->create()->id,
            'label' => null,
            'latitude' => '41.311081',
            'longitude' => '69.240562',
            'street' => 'Amir Temur',
            'house' => '12',
            'apartment' => null,
            'landmark' => null,
            'delivery_note' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ], $overrides);
    }

    public function test_it_has_exactly_the_columns_the_schema_names_with_their_types(): void
    {
        $actual = $this->columnsOf(self::TABLE);

        $names = array_keys($actual);
        $expectedNames = array_keys($this->expectedColumns());
        sort($names);
        sort($expectedNames);
        $this->assertSame($expectedNames, $names);

        foreach ($this->expectedColumns() as $column => [$type, $nullable]) {
            $this->assertSame($type, $actual[$column]->data_type, self::TABLE.".{$column} type");
            $this->assertSame($nullable ? 'YES' : 'NO', $actual[$column]->is_nullable, self::TABLE.".{$column} nullability");
        }
    }

    public function test_a_valid_address_is_accepted_and_active_by_default(): void
    {
        DB::table(self::TABLE)->insert($this->row());

        $this->assertTrue((bool) DB::table(self::TABLE)->value('is_active'));
    }

    public function test_it_indexes_the_owner_with_the_active_flag(): void
    {
        $this->assertStringContainsString(
            '(customer_id, is_active)',
            $this->indexesOn(self::TABLE)['customer_addresses_customer_id_is_active_index']
        );
    }

    public function test_the_extreme_coordinates_are_accepted(): void
    {
        DB::table(self::TABLE)->insert($this->row(['latitude' => '90.000000', 'longitude' => '180.000000']));
        DB::table(self::TABLE)->insert($this->row(['latitude' => '-90.000000', 'longitude' => '-180.000000']));

        $this->assertSame(2, DB::table(self::TABLE)->count());
    }

    public function test_coordinates_outside_their_ranges_are_rejected(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'customer_addresses_latitude_range_check',
            $this->row(['latitude' => '91.000000']),
            'A latitude above 90 is not a point on Earth.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'customer_addresses_longitude_range_check',
            $this->row(['longitude' => '-181.000000']),
            'A longitude below -180 is not a point on Earth.'
        );
    }

    public function test_a_blank_street_or_house_is_rejected(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'customer_addresses_street_not_blank_check',
            $this->row(['street' => '   ']),
            'BR-CHK-002 requires a street; whitespace is not one.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'customer_addresses_house_not_blank_check',
            $this->row(['house' => '']),
            'BR-CHK-002 requires a house.'
        );
    }

    public function test_the_owner_cannot_be_deleted_while_an_address_refers_to_it(): void
    {
        $customer = User::factory()->customer()->create();
        DB::table(self::TABLE)->insert($this->row(['customer_id' => $customer->id]));

        $this->expectException(QueryException::class);
        $this->expectExceptionMessage('customer_addresses_customer_id_foreign');

        DB::table('users')->where('id', $customer->id)->delete();
    }
}
