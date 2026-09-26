<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

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
 * `categories`, as `docs/08-database.md` Section 6 names it.
 */
final class CategoriesTableTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    private const TABLE = 'categories';

    /**
     * @return array<string, array{string, bool}>
     */
    private function expectedColumns(): array
    {
        return [
            'id' => ['uuid', false],
            'name_uz' => ['character varying', false],
            'name_ru' => ['character varying', false],
            'description_uz' => ['text', true],
            'description_ru' => ['text', true],
            'sort_order' => ['integer', false],
            'is_active' => ['boolean', false],
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
            'name_uz' => 'Sabzavotlar',
            'name_ru' => 'Овощи',
            'description_uz' => null,
            'description_ru' => null,
            'sort_order' => 0,
            'is_active' => true,
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

    public function test_it_indexes_the_listing_order_and_both_lower_cased_names(): void
    {
        $indexes = $this->indexesOn(self::TABLE);

        $this->assertStringContainsString('(is_active, sort_order)', $indexes['categories_is_active_sort_order_index']);
        $this->assertStringContainsString('lower((name_uz)::text)', $indexes['categories_name_uz_lower_index']);
        $this->assertStringContainsString('lower((name_ru)::text)', $indexes['categories_name_ru_lower_index']);
    }

    public function test_a_valid_category_is_accepted(): void
    {
        DB::table(self::TABLE)->insert($this->row());

        $this->assertSame(1, DB::table(self::TABLE)->count());
    }

    public function test_a_blank_name_in_either_language_is_rejected(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'categories_name_uz_not_blank_check',
            $this->row(['name_uz' => ' ']),
            'BR-CAT-005 requires both names.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'categories_name_ru_not_blank_check',
            $this->row(['name_ru' => '']),
            'BR-CAT-005 requires both names.'
        );
    }

    public function test_an_archived_category_cannot_be_active(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'categories_archived_inactive_check',
            $this->row(['archived_at' => now(), 'is_active' => true]),
            'Archiving takes a category out of use; the two columns may not disagree.'
        );
    }

    public function test_the_creator_cannot_be_deleted_while_a_category_refers_to_it(): void
    {
        $admin = User::factory()->role(Role::Admin)->create();
        DB::table(self::TABLE)->insert($this->row(['created_by_user_id' => $admin->id]));

        $this->expectException(QueryException::class);
        $this->expectExceptionMessage('categories_created_by_user_id_foreign');

        DB::table('users')->where('id', $admin->id)->delete();
    }
}
