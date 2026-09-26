<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use App\Models\Category;
use App\Models\Enums\Role;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\Database\AssertsDatabaseRejections;
use Tests\Support\Database\ReadsPostgresCatalog;
use Tests\TestCase;

/**
 * `products`, as `docs/08-database.md` Section 7 names it.
 */
final class ProductsTableTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    private const TABLE = 'products';

    /**
     * @return array<string, array{string, bool}>
     */
    private function expectedColumns(): array
    {
        return [
            'id' => ['uuid', false],
            'category_id' => ['uuid', false],
            'name_uz' => ['character varying', false],
            'name_ru' => ['character varying', false],
            'description_uz' => ['text', true],
            'description_ru' => ['text', true],
            'unit_code' => ['character varying', false],
            'price_mode' => ['character varying', false],
            'market_price_uzs' => ['bigint', false],
            'is_active' => ['boolean', false],
            'sort_order' => ['integer', false],
            'archived_at' => ['timestamp with time zone', true],
            'created_by_user_id' => ['uuid', false],
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
            'category_id' => Category::factory()->create()->id,
            'name_uz' => 'Pomidor',
            'name_ru' => 'Помидор',
            'description_uz' => null,
            'description_ru' => null,
            'unit_code' => 'kg',
            'price_mode' => 'estimate',
            'market_price_uzs' => 16000,
            'is_active' => true,
            'sort_order' => 0,
            'archived_at' => null,
            'created_by_user_id' => User::factory()->role(Role::Admin)->create()->id,
            'created_at' => now(),
            'updated_at' => now(),
        ], $overrides);
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

    public function test_there_is_no_stored_customer_price(): void
    {
        // BR-PRICE-001 computes it from the market price and the current markup;
        // a stored copy would go stale the moment the markup changed.
        $this->assertArrayNotHasKey('customer_unit_price_uzs', $this->columnsOf(self::TABLE));
    }

    public function test_it_indexes_category_listing_order_and_both_lower_cased_names(): void
    {
        $indexes = $this->indexesOn(self::TABLE);

        $this->assertStringContainsString('(category_id, is_active)', $indexes['products_category_id_is_active_index']);
        $this->assertStringContainsString('(is_active, sort_order)', $indexes['products_is_active_sort_order_index']);
        $this->assertStringContainsString('lower((name_uz)::text)', $indexes['products_name_uz_lower_index']);
        $this->assertStringContainsString('lower((name_ru)::text)', $indexes['products_name_ru_lower_index']);
    }

    public function test_a_valid_product_is_accepted(): void
    {
        DB::table(self::TABLE)->insert($this->row());

        $this->assertSame(1, DB::table(self::TABLE)->count());
    }

    public function test_a_unit_outside_the_approved_list_is_rejected(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'products_unit_code_check',
            $this->row(['unit_code' => 'ton']),
            'BR-QTY-001 names eight units; a ninth is a product decision.'
        );
    }

    public function test_a_price_mode_outside_fixed_and_estimate_is_rejected(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'products_price_mode_check',
            $this->row(['price_mode' => 'range']),
            'DL-2 2.2 removed the range and at_purchase modes.'
        );
    }

    public function test_a_market_price_that_is_not_positive_is_rejected(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'products_market_price_positive_check',
            $this->row(['market_price_uzs' => 0]),
            'No product is ever shown without a price (DL-2 2.2).'
        );
    }

    public function test_a_blank_name_and_an_archived_active_product_are_rejected(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'products_name_uz_not_blank_check',
            $this->row(['name_uz' => '']),
            'BR-CAT-005 requires both names.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'products_name_ru_not_blank_check',
            $this->row(['name_ru' => '  ']),
            'BR-CAT-005 requires both names.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'products_archived_inactive_check',
            $this->row(['archived_at' => now(), 'is_active' => true]),
            'An archived product may not stay active.'
        );
    }

    public function test_a_category_cannot_be_deleted_while_a_product_refers_to_it(): void
    {
        $category = Category::factory()->create();
        DB::table(self::TABLE)->insert($this->row(['category_id' => $category->id]));

        $this->expectException(QueryException::class);
        $this->expectExceptionMessage('products_category_id_foreign');

        DB::table('categories')->where('id', $category->id)->delete();
    }
}
