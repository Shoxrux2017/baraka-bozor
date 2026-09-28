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
            'approved_replacement_price_uzs' => ['bigint', true],
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

        // A replacement is billed at its own price (BR-PRICE-004): 15 652 paid,
        // half_up(15 652 × 1.15) = 18 000.
        $replacement = Product::factory()->create();
        DB::table(self::TABLE)->insert($this->purchased([
            'price_mode_snapshot' => 'fixed',
            'actual_market_price_uzs' => 15652,
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

    public function test_a_line_billed_from_the_price_paid_records_it_and_is_billed_by_its_markup(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_actual_price_check',
            $this->purchased(['actual_market_price_uzs' => null]),
            'docs/08 section 14: an estimate line records the price paid.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_billable_price_check',
            $this->purchased(['billable_unit_price_uzs' => 18401, 'line_total_uzs' => 92005]),
            'BR-PRICE-003: half_up(16 000 × 1.15) = 18 400, not 18 401.'
        );

        // A fixed line bought as a replacement is billed from the price paid
        // too (BR-PRICE-004): the rule is the replacement's, not the mode's.
        $replaced = [
            'price_mode_snapshot' => 'fixed',
            'fulfilled_product_id' => Product::factory()->create()->id,
            'substitution_resolution' => 'automatic',
        ];
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_actual_price_check',
            $this->purchased([...$replaced, 'actual_market_price_uzs' => null]),
            'A replacement of a fixed line records the price paid.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_billable_price_check',
            $this->purchased([...$replaced, 'actual_market_price_uzs' => 15652]),
            'A replacement at 15 652 paid is billed 18 000, not the original\'s 18 400.'
        );

        // A line keeps the markup it was priced with (DL-37 (8)): 16 000 at
        // 12.5 % is 18 000.
        DB::table(self::TABLE)->insert($this->purchased([
            'markup_percent_snapshot' => '12.50',
            'billable_unit_price_uzs' => 18000,
            'line_total_uzs' => 90000,
        ]));

        // A fixed line bought as itself needs no price paid.
        DB::table(self::TABLE)->insert($this->purchased([
            'price_mode_snapshot' => 'fixed',
            'actual_market_price_uzs' => null,
        ]));

        $this->assertSame(2, DB::table(self::TABLE)->count());
    }

    public function test_a_replacement_keeps_the_unit_says_how_it_was_authorized_and_alone_carries_an_approved_price(): void
    {
        $replacement = Product::factory()->create();
        $authorized = [
            'fulfilled_product_id' => $replacement->id,
            'fulfilled_product_name_uz_snapshot' => 'Olcha',
            'fulfilled_product_name_ru_snapshot' => 'Вишня',
            'fulfilled_unit_code_snapshot' => 'kg',
            'substitution_resolution' => 'automatic',
        ];

        $this->assertRejectedBy(
            self::TABLE,
            'order_items_approved_replacement_price_check',
            $this->row(['approved_replacement_price_uzs' => 20000]),
            'DL-54 (5): an approved replacement price belongs to a replacement.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_approved_replacement_price_check',
            $this->row([...$authorized, 'approved_replacement_price_uzs' => 0]),
            'An approved price is positive.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_same_unit_check',
            $this->row([...$authorized, 'fulfilled_unit_code_snapshot' => 'piece']),
            'BR-ITEM-004: a replacement has the original\'s unit.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_substitution_target_check',
            $this->row([...$authorized, 'substitution_resolution' => null]),
            'DL-3 S-9: a replacement says how it was authorized.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_substitution_target_check',
            $this->purchased(['substitution_resolution' => 'automatic']),
            'The original bought as itself is no replacement.'
        );

        $this->assertRejectedBy(
            self::TABLE,
            'order_items_approved_replacement_price_check',
            $this->purchased(['approved_replacement_price_uzs' => 20000]),
            'DL-54 (4): buying the original drops the replacement\'s approved price.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_approved_substitution_check',
            $this->row([...$authorized, 'substitution_resolution' => 'approved']),
            'An approved substitution carries the price the Customer approved.'
        );

        DB::table(self::TABLE)->insert($this->row([...$authorized, 'approved_replacement_price_uzs' => 20000]));
        DB::table(self::TABLE)->insert($this->row([...$authorized, 'substitution_resolution' => 'approved', 'approved_replacement_price_uzs' => 12650]));
        $this->assertSame(2, DB::table(self::TABLE)->count());
    }

    public function test_an_approved_price_binds_what_is_bought_and_a_fixed_line_takes_none(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_fixed_ceiling_check',
            $this->row(['price_mode_snapshot' => 'fixed', 'approved_unit_price_ceiling_uzs' => 20000]),
            'DL-54 (5): no approval raises a fixed original\'s ceiling.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_within_approval_check',
            $this->purchased(['approved_unit_price_ceiling_uzs' => 18000]),
            'BR-APP-008: the original is bought within its approved ceiling.'
        );

        $replacement = [
            'fulfilled_product_id' => Product::factory()->create()->id,
            'substitution_resolution' => 'approved',
        ];
        $this->assertRejectedBy(
            self::TABLE,
            'order_items_within_approval_check',
            $this->purchased([...$replacement, 'approved_replacement_price_uzs' => 18000]),
            'BR-APP-009: the replacement is bought within the price approved for it.'
        );

        // The original's ceiling does not bind the replacement, nor the other way round.
        DB::table(self::TABLE)->insert($this->purchased([...$replacement, 'approved_unit_price_ceiling_uzs' => 18000, 'approved_replacement_price_uzs' => 18400]));
        DB::table(self::TABLE)->insert($this->purchased(['approved_unit_price_ceiling_uzs' => 18400]));
        $this->assertSame(2, DB::table(self::TABLE)->count());
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
