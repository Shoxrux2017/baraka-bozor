<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use App\Models\Enums\Role;
use App\Models\OrderItem;
use App\Models\User;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\Database\AssertsDatabaseRejections;
use Tests\Support\Database\ReadsPostgresCatalog;
use Tests\TestCase;

/**
 * `order_item_price_corrections`, as `docs/08-database.md` Section 19 names
 * it: positive prices, a change, a reason, and append-only (`BR-PRICE-006`,
 * `DL-54` (18)).
 */
final class OrderItemPriceCorrectionsTableTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    private const TABLE = 'order_item_price_corrections';

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function row(array $overrides = []): array
    {
        return array_merge([
            'id' => (string) Str::uuid(),
            'order_item_id' => OrderItem::factory()->purchased()->create()->id,
            'old_actual_market_price_uzs' => 16000,
            'new_actual_market_price_uzs' => 15000,
            'old_billable_unit_price_uzs' => 18400,
            'new_billable_unit_price_uzs' => 17250,
            'corrected_by_user_id' => User::factory()->role(Role::Admin)->create()->id,
            'reason' => 'Опечатка в цене',
            'created_at' => now(),
        ], $overrides);
    }

    public function test_it_has_exactly_the_columns_the_schema_names(): void
    {
        $this->assertColumns(self::TABLE, [
            'id' => ['uuid', false],
            'order_item_id' => ['uuid', false],
            'old_actual_market_price_uzs' => ['bigint', false],
            'new_actual_market_price_uzs' => ['bigint', false],
            'old_billable_unit_price_uzs' => ['bigint', false],
            'new_billable_unit_price_uzs' => ['bigint', false],
            'corrected_by_user_id' => ['uuid', false],
            'reason' => ['character varying', false, 300],
            'created_at' => ['timestamp with time zone', false],
        ]);
        $this->assertStringContainsString(
            '(order_item_id, created_at)',
            $this->indexesOn(self::TABLE)['order_item_price_corrections_order_item_id_created_at_index']
        );
    }

    public function test_a_correction_changes_a_positive_price_for_a_reason(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'order_item_price_corrections_changed_check',
            $this->row(['new_actual_market_price_uzs' => 16000, 'new_billable_unit_price_uzs' => 18400]),
            'DL-54 (18): the current price again writes nothing.'
        );
        foreach (['old_actual_market_price_uzs', 'old_billable_unit_price_uzs', 'new_billable_unit_price_uzs'] as $column) {
            $this->assertRejectedBy(self::TABLE, 'order_item_price_corrections_prices_check', $this->row([$column => 0]), "{$column} is positive.");
        }
        $this->assertRejectedBy(self::TABLE, 'order_item_price_corrections_reason_check', $this->row(['reason' => ' ']), 'BR-PRICE-006: with a reason.');
    }

    public function test_a_correction_cannot_be_changed_or_deleted(): void
    {
        $row = $this->row();
        DB::table(self::TABLE)->insert($row);

        foreach ([
            fn () => DB::table(self::TABLE)->where('id', $row['id'])->update(['reason' => 'rewritten']),
            fn () => DB::table(self::TABLE)->where('id', $row['id'])->delete(),
        ] as $change) {
            DB::beginTransaction();

            try {
                $change();
                $this->fail('A correction is an audit; it is never rewritten.');
            } catch (QueryException $refusal) {
                $this->assertStringContainsString('order_item_price_corrections is append-only', $refusal->getMessage());
            } finally {
                DB::rollBack();
            }
        }

        $this->assertSame('Опечатка в цене', DB::table(self::TABLE)->where('id', $row['id'])->value('reason'));
    }
}
