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
 * markup snapshot (`DL-37` (8)): the quantity rules of `05` Section 4, the
 * money rules a stored line can hold, and what each item state implies
 * (`DL-38`).
 *
 * Each check is proven by a row only it refuses. PostgreSQL evaluates checks
 * in name order, so a row meant for one check satisfies every check named
 * before it.
 */
final class OrderItemsTableTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    private const TABLE = 'order_items';

    private Product $product;

    protected function setUp(): void
    {
        parent::setUp();

        $this->product = Product::factory()->create();
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function row(array $overrides = []): array
    {
        return array_merge([
            'id' => (string) Str::uuid(),
            'order_id' => Order::factory()->create()->id,
            'product_id' => $this->product->id,
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
     * An estimate line bought 5.2 kg for 5 ordered, billed 5 at 18 400.
     *
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function purchased(array $overrides = []): array
    {
        return $this->row(array_merge([
            'status' => 'purchased',
            'purchased_quantity' => '5.200',
            'billable_quantity' => '5.000',
            'actual_market_price_uzs' => 16000,
            'billable_unit_price_uzs' => 18400,
            'line_total_uzs' => 92000,
            'fulfilled_product_id' => $this->product->id,
            'fulfilled_product_name_uz_snapshot' => 'Pomidor',
            'fulfilled_product_name_ru_snapshot' => 'Помидор',
            'fulfilled_unit_code_snapshot' => 'kg',
        ], $overrides));
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function removed(array $overrides = []): array
    {
        return $this->row(array_merge([
            'status' => 'removed',
            'removed_reason_code' => 'customer_removed',
            'removed_at' => now(),
            'line_total_uzs' => 0,
        ], $overrides));
    }

    public function test_it_has_exactly_the_columns_the_schema_names_with_their_types_and_lengths(): void
    {
        $this->assertColumns(self::TABLE, [
            'id' => ['uuid', false],
            'order_id' => ['uuid', false],
            'product_id' => ['uuid', false],
            'product_name_uz_snapshot' => ['character varying', false, 160],
            'product_name_ru_snapshot' => ['character varying', false, 160],
            'unit_code_snapshot' => ['character varying', false, 16],
            'price_mode_snapshot' => ['character varying', false, 16],
            'market_price_uzs_snapshot' => ['bigint', false],
            'customer_unit_price_uzs_snapshot' => ['bigint', false],
            'markup_percent_snapshot' => ['numeric', false],
            'ordered_quantity' => ['numeric', false],
            'purchased_quantity' => ['numeric', true],
            'billable_quantity' => ['numeric', false],
            'customer_note_snapshot' => ['character varying', true, 300],
            'substitution_policy_snapshot' => ['character varying', false, 40],
            'status' => ['character varying', false, 24],
            'approved_quantity_cap' => ['numeric', true],
            'approved_unit_price_ceiling_uzs' => ['bigint', true],
            'fulfilled_product_id' => ['uuid', true],
            'fulfilled_product_name_uz_snapshot' => ['character varying', true, 160],
            'fulfilled_product_name_ru_snapshot' => ['character varying', true, 160],
            'fulfilled_unit_code_snapshot' => ['character varying', true, 16],
            'substitution_resolution' => ['character varying', true, 16],
            'actual_market_price_uzs' => ['bigint', true],
            'billable_unit_price_uzs' => ['bigint', true],
            'line_total_uzs' => ['bigint', true],
            'removed_reason_code' => ['character varying', true, 40],
            'removed_at' => ['timestamp with time zone', true],
            'created_at' => ['timestamp with time zone', false],
            'updated_at' => ['timestamp with time zone', false],
        ]);
    }

    public function test_a_pending_line_an_excess_purchase_billed_as_ordered_and_a_removed_line_are_accepted(): void
    {
        DB::table(self::TABLE)->insert($this->row());
        DB::table(self::TABLE)->insert($this->purchased());
        DB::table(self::TABLE)->insert($this->removed());

        $this->assertSame(3, DB::table(self::TABLE)->count());
    }

    public function test_the_billable_quantity_never_exceeds_the_order_or_an_approved_cap(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_quantities_check',
            $this->purchased(['purchased_quantity' => '6.000', 'billable_quantity' => '5.200', 'line_total_uzs' => 95680]),
            'BR-QTY-003: excess purchase is never billed.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_quantities_check',
            $this->purchased(['approved_quantity_cap' => '4.000']),
            'BR-QTY-006: an approved reduction caps the bill.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_quantities_check',
            $this->row(['approved_quantity_cap' => '5.000']),
            'A cap is a reduction, below the ordered quantity.'
        );
        $this->assertRejectedBy(self::TABLE, 'order_items_quantities_check', $this->row(['ordered_quantity' => '0']), 'BR-QTY-001: positive.');
        $this->assertRejectedBy(self::TABLE, 'order_items_quantities_check', $this->row(['purchased_quantity' => '0']), 'A purchase buys something.');
    }

    public function test_every_stored_price_is_positive_and_the_markup_not_negative(): void
    {
        foreach ([
            'market_price_uzs_snapshot' => 0,
            'customer_unit_price_uzs_snapshot' => 0,
            'markup_percent_snapshot' => '-1',
            'approved_unit_price_ceiling_uzs' => 0,
            'actual_market_price_uzs' => 0,
        ] as $column => $value) {
            $this->assertRejectedBy(self::TABLE, 'order_items_prices_check', $this->row([$column => $value]), "{$column} out of range.");
        }

        $this->assertRejectedBy(
            self::TABLE,
            'order_items_prices_check',
            $this->removed(['line_total_uzs' => 0, 'billable_unit_price_uzs' => 0]),
            'A billable price is positive.'
        );
    }

    public function test_a_line_total_is_its_price_times_its_quantity_rounded_half_up(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_line_total_check',
            $this->purchased(['line_total_uzs' => 92001]),
            'BR-MONEY-003.'
        );

        // 18 401 × 5.500 = 101 205.5, half-up to 101 206.
        DB::table(self::TABLE)->insert($this->purchased([
            'ordered_quantity' => '5.500',
            'purchased_quantity' => '5.500',
            'billable_quantity' => '5.500',
            'billable_unit_price_uzs' => 18401,
            'actual_market_price_uzs' => 16001,
            'line_total_uzs' => 101206,
        ]));
        $this->assertSame(1, DB::table(self::TABLE)->count());
    }

    public function test_a_fixed_line_bought_as_itself_is_billed_at_its_snapshot(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_fixed_price_check',
            $this->purchased(['price_mode_snapshot' => 'fixed', 'billable_unit_price_uzs' => 18000, 'line_total_uzs' => 90000]),
            'BR-PRICE-002: the Customer pays the shown price whatever the Shopper paid.'
        );

        // A replacement is billed at its own price (BR-PRICE-004).
        $replacement = Product::factory()->create();
        DB::table(self::TABLE)->insert($this->purchased([
            'price_mode_snapshot' => 'fixed',
            'billable_unit_price_uzs' => 18000,
            'line_total_uzs' => 90000,
            'fulfilled_product_id' => $replacement->id,
            'substitution_resolution' => 'automatic',
        ]));
        $this->assertSame(1, DB::table(self::TABLE)->count());
    }

    public function test_each_state_carries_what_it_implies(): void
    {
        foreach (['purchased_quantity', 'billable_unit_price_uzs', 'line_total_uzs'] as $column) {
            $this->assertRejectedBy(
                self::TABLE,
                'order_items_purchased_check',
                $this->purchased([$column => null]),
                "BR-ITEM-002: a purchased line has its {$column}."
            );
        }
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_purchased_check',
            $this->purchased(['fulfilled_product_id' => null, 'fulfilled_product_name_uz_snapshot' => null, 'fulfilled_product_name_ru_snapshot' => null, 'fulfilled_unit_code_snapshot' => null]),
            'A purchased line names what was bought.'
        );
        foreach (['pending', 'awaiting_customer'] as $status) {
            $this->assertRejectedBy(
                self::TABLE,
                'order_items_open_check',
                $this->row(['status' => $status, 'billable_quantity' => '1.000']),
                "Nothing is billable while {$status}."
            );
        }
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_removed_check',
            $this->removed(['removed_reason_code' => null]),
            'BR-ITEM-003: a removed line says why.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_removed_check',
            $this->removed(['removed_at' => null]),
            'A removed line says when.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_removed_check',
            $this->removed(['line_total_uzs' => 100]),
            'BR-ITEM-003: a removed line bills nothing.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_removed_check',
            $this->removed(['line_total_uzs' => null]),
            'BR-ITEM-003: the zero line total is stored, not left null.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_fulfilled_product_check',
            $this->row(['fulfilled_product_id' => $this->product->id]),
            'A fulfilled product comes with its snapshot.'
        );
    }

    public function test_the_vocabularies_and_the_names_are_enforced(): void
    {
        $this->assertRejectedBy(self::TABLE, 'order_items_unit_code_check', $this->row(['unit_code_snapshot' => 'ton']), 'BR-QTY-001.');
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_fulfilled_unit_code_check',
            $this->row([
                'fulfilled_product_id' => $this->product->id,
                'fulfilled_product_name_uz_snapshot' => 'Pomidor',
                'fulfilled_product_name_ru_snapshot' => 'Помидор',
                'fulfilled_unit_code_snapshot' => 'ton',
            ]),
            'BR-QTY-001, for the replacement too.'
        );
        $this->assertRejectedBy(self::TABLE, 'order_items_price_mode_check', $this->row(['price_mode_snapshot' => 'range']), 'DL-2 2.2.');
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_substitution_policy_check',
            $this->row(['substitution_policy_snapshot' => 'substitute_anything']),
            'Three rules only.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_substitution_resolution_check',
            $this->row(['substitution_resolution' => 'manual']),
            'DL-3 S-9: automatic or approved.'
        );
        $this->assertRejectedBy(self::TABLE, 'order_items_status_check', $this->row(['status' => 'bought']), '05 Section 10.');
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_removed_reason_check',
            $this->removed(['removed_reason_code' => 'deleted']),
            'DL-3 S-9.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_names_not_blank_check',
            $this->row(['product_name_ru_snapshot' => ' ']),
            'BR-CAT-005: both names, snapshotted.'
        );
    }
}
