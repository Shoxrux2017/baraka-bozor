<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * What Wave 3's shopping writes onto `order_items`, held by the database for
 * any writer (`DL-54` (2), (4), (5), `DL-55`).
 *
 * - `approved_replacement_price_uzs`: the price the Customer approved for the
 *   authorized replacement, beside `approved_unit_price_ceiling_uzs`, which
 *   stays the original's; it exists only on a line with a replacement.
 * - A replacement is named with how it was authorized, and only a
 *   replacement is (`DL-3` S-9).
 * - A replacement has the original's unit (`BR-ITEM-004`).
 * - A line billed from the price paid — an estimate, or any replacement —
 *   records that price and is billed at `half_up(price × (1 + line markup /
 *   100))` (`BR-PRICE-003`, `BR-PRICE-004`, `DL-37` (8)); `round()` on a
 *   non-negative numeric is half-up (`DL-38` (2)).
 * - A fixed line never has an approved ceiling: no approval raises a fixed
 *   original's (`DL-54` (5), `BR-PRICE-005`).
 * - An approved substitution has the price the Customer approved.
 * - A purchase is billed within the price the Customer approved for what was
 *   bought: the original's approved ceiling, or the replacement's approved
 *   price (`BR-APP-008`, `BR-APP-009`).
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement('alter table order_items add column approved_replacement_price_uzs bigint');

        $this->check(
            'order_items_approved_replacement_price_check',
            'approved_replacement_price_uzs is null or (approved_replacement_price_uzs > 0'
            .' and fulfilled_product_id is not null and fulfilled_product_id <> product_id)'
        );
        $this->check(
            'order_items_substitution_target_check',
            '(substitution_resolution is null) = (fulfilled_product_id is null or fulfilled_product_id = product_id)'
        );
        $this->check(
            'order_items_same_unit_check',
            'fulfilled_unit_code_snapshot is null or fulfilled_unit_code_snapshot = unit_code_snapshot'
        );
        $this->check(
            'order_items_actual_price_check',
            "status <> 'purchased' or (price_mode_snapshot = 'fixed' and fulfilled_product_id = product_id)"
            .' or actual_market_price_uzs is not null'
        );
        $this->check('order_items_fixed_ceiling_check', "price_mode_snapshot <> 'fixed' or approved_unit_price_ceiling_uzs is null");
        $this->check(
            'order_items_approved_substitution_check',
            "coalesce(substitution_resolution, '') <> 'approved' or approved_replacement_price_uzs is not null"
        );
        $this->check(
            'order_items_within_approval_check',
            "status <> 'purchased' or (fulfilled_product_id = product_id and (approved_unit_price_ceiling_uzs is null"
            .' or billable_unit_price_uzs <= approved_unit_price_ceiling_uzs))'
            .' or (fulfilled_product_id <> product_id and (approved_replacement_price_uzs is null'
            .' or billable_unit_price_uzs <= approved_replacement_price_uzs))'
        );
        $this->check(
            'order_items_billable_price_check',
            "status <> 'purchased' or (price_mode_snapshot = 'fixed' and fulfilled_product_id = product_id)"
            .' or billable_unit_price_uzs = round(actual_market_price_uzs * (100 + markup_percent_snapshot) / 100)'
        );
    }

    public function down(): void
    {
        foreach ([
            'order_items_within_approval_check',
            'order_items_approved_substitution_check',
            'order_items_fixed_ceiling_check',
            'order_items_billable_price_check',
            'order_items_actual_price_check',
            'order_items_same_unit_check',
            'order_items_substitution_target_check',
            'order_items_approved_replacement_price_check',
        ] as $check) {
            DB::statement("alter table order_items drop constraint {$check}");
        }

        DB::statement('alter table order_items drop column approved_replacement_price_uzs');
    }

    private function check(string $name, string $expression): void
    {
        DB::statement("alter table order_items add constraint {$name} check ({$expression})");
    }
};
