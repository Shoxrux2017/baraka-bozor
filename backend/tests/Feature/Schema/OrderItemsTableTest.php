<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use App\Models\Order;
use App\Models\Product;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\Database\AssertsDatabaseRejections;
use Tests\Support\Database\ReadsPostgresCatalog;
use Tests\TestCase;

/**
 * `order_items`, as `docs/08-database.md` Section 14 names it, with the line's
 * markup snapshot (`DL-37` (8)): the quantity rules of `05` Section 4 and what
 * each item state implies.
 */
final class OrderItemsTableTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    private const TABLE = 'order_items';

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function row(array $overrides = []): array
    {
        $product = Product::factory()->create();

        return array_merge([
            'id' => (string) Str::uuid(),
            'order_id' => Order::factory()->create()->id,
            'product_id' => $product->id,
            'product_name_uz_snapshot' => 'Pomidor',
            'product_name_ru_snapshot' => 'Помидор',
            'unit_code_snapshot' => 'kg',
            'price_mode_snapshot' => 'estimate',
            'market_price_uzs_snapshot' => 16000,
            'customer_unit_price_uzs_snapshot' => 18400,
            'markup_percent_snapshot' => '15.00',
            'ordered_quantity' => '5.000',
            'billable_quantity' => '0',
            'substitution_policy_snapshot' => 'allow_similar_substitution',
            'status' => 'pending',
            'created_at' => now(),
            'updated_at' => now(),
        ], $overrides);
    }

    /**
     * @return array<string, mixed>
     */
    private function purchased(Product $product): array
    {
        return [
            'status' => 'purchased',
            'product_id' => $product->id,
            'purchased_quantity' => '5.200',
            'billable_quantity' => '5.000',
            'billable_unit_price_uzs' => 18400,
            'line_total_uzs' => 92000,
            'fulfilled_product_id' => $product->id,
            'fulfilled_product_name_uz_snapshot' => 'Pomidor',
            'fulfilled_product_name_ru_snapshot' => 'Помидор',
            'fulfilled_unit_code_snapshot' => 'kg',
        ];
    }

    public function test_the_line_carries_its_own_markup_snapshot(): void
    {
        $columns = $this->columnsOf(self::TABLE);

        $this->assertSame('numeric', $columns['markup_percent_snapshot']->data_type);
        $this->assertSame('NO', $columns['markup_percent_snapshot']->is_nullable);
    }

    public function test_a_pending_line_and_an_excess_purchase_billed_as_ordered_are_accepted(): void
    {
        DB::table(self::TABLE)->insert($this->row());
        DB::table(self::TABLE)->insert($this->row($this->purchased(Product::factory()->create())));

        $this->assertSame(2, DB::table(self::TABLE)->count());
    }

    public function test_the_billable_quantity_never_exceeds_the_order_or_an_approved_cap(): void
    {
        $product = Product::factory()->create();

        $this->assertRejectedBy(
            self::TABLE,
            'order_items_quantities_check',
            $this->row(array_merge($this->purchased($product), ['purchased_quantity' => '6.000', 'billable_quantity' => '5.200'])),
            'BR-QTY-003: excess purchase is never billed.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_quantities_check',
            $this->row(array_merge($this->purchased($product), ['approved_quantity_cap' => '4.000'])),
            'BR-QTY-006: an approved reduction caps the bill.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_quantities_check',
            $this->row(['approved_quantity_cap' => '5.000']),
            'A cap is a reduction, below the ordered quantity.'
        );
        $this->assertRejectedBy(self::TABLE, 'order_items_quantities_check', $this->row(['ordered_quantity' => '0']), 'BR-QTY-001: positive.');
    }

    public function test_each_state_carries_what_it_implies(): void
    {
        $product = Product::factory()->create();

        $this->assertRejectedBy(
            self::TABLE,
            'order_items_purchased_check',
            $this->row(array_merge($this->purchased($product), ['line_total_uzs' => null])),
            'BR-ITEM-002: a purchased line has its total.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_open_check',
            $this->row(['billable_quantity' => '1.000']),
            'Nothing is billable before it is bought.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_removed_check',
            $this->row(['status' => 'removed', 'removed_at' => now()]),
            'BR-ITEM-003: a removed line says why.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_removed_check',
            $this->row(['status' => 'removed', 'removed_at' => now(), 'removed_reason_code' => 'customer_removed', 'line_total_uzs' => 100]),
            'BR-ITEM-003: a removed line bills nothing.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_removed_check',
            $this->row(['status' => 'removed', 'removed_at' => now(), 'removed_reason_code' => 'customer_removed']),
            'BR-ITEM-003: the zero line total is stored, not left null.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_fulfilled_product_check',
            $this->row(['fulfilled_product_id' => $product->id]),
            'A fulfilled product comes with its snapshot.'
        );
    }

    public function test_the_vocabularies_are_enforced(): void
    {
        $this->assertRejectedBy(self::TABLE, 'order_items_unit_code_check', $this->row(['unit_code_snapshot' => 'ton']), 'BR-QTY-001.');
        $this->assertRejectedBy(self::TABLE, 'order_items_status_check', $this->row(['status' => 'bought']), '05 Section 10.');
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_removed_reason_check',
            $this->row(['status' => 'removed', 'removed_at' => now(), 'removed_reason_code' => 'deleted', 'line_total_uzs' => 0]),
            'DL-3 S-9.'
        );
        $this->assertRejectedBy(self::TABLE, 'order_items_prices_check', $this->row(['customer_unit_price_uzs_snapshot' => 0]), 'Every line has a price.');
    }
}
