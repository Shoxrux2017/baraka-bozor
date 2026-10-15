<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\Database\AssertsDatabaseRejections;
use Tests\Support\Database\ReadsPostgresCatalog;
use Tests\TestCase;

/**
 * `customer_favorites`, as `docs/08-database.md` Section 32 names it.
 */
final class CustomerFavoritesTableTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    private const TABLE = 'customer_favorites';

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function row(array $overrides = []): array
    {
        return array_merge([
            'id' => (string) Str::uuid(),
            'customer_id' => User::factory()->customer()->create()->id,
            'product_id' => Product::factory()->create()->id,
            'created_at' => now(),
        ], $overrides);
    }

    public function test_it_has_exactly_the_columns_the_schema_names_with_their_types(): void
    {
        $expected = [
            'id' => ['uuid'],
            'customer_id' => ['uuid'],
            'product_id' => ['uuid'],
            'created_at' => ['timestamp with time zone'],
        ];
        $actual = $this->columnsOf(self::TABLE);

        $this->assertEqualsCanonicalizing(array_keys($expected), array_keys($actual));
        foreach ($expected as $column => [$type]) {
            $this->assertSame($type, $actual[$column]->data_type, self::TABLE.".{$column} type");
            $this->assertSame('NO', $actual[$column]->is_nullable, self::TABLE.".{$column} nullability");
        }
    }

    public function test_a_customer_favours_a_product_at_most_once(): void
    {
        $row = $this->row();
        DB::table(self::TABLE)->insert($row);

        $this->assertRejectedBy(
            self::TABLE,
            'customer_favorites_customer_id_product_id_unique',
            $this->row(['customer_id' => $row['customer_id'], 'product_id' => $row['product_id']]),
            'One row per Customer and product.'
        );
    }
}
