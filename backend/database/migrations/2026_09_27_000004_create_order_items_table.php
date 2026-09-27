<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `order_items`, as `docs/08-database.md` Section 14 names it, with the line's
 * own markup snapshot (`DL-37` (8)).
 *
 * The line keeps both names, the unit, the price mode, the prices and the
 * markup it was ordered at, so a later catalog or settings change never reaches
 * it (`BR-CORE-004`). The ordered quantity is the Customer's contract and the
 * billable quantity never exceeds it or an approved cap (`BR-QTY-002`,
 * `BR-QTY-003`, `BR-QTY-006`).
 *
 * Every column of shopping and substitution is created now although Wave 3
 * fills them, so the table never has to be reshaped once it holds orders.
 */
return new class extends Migration
{
    /** @var list<string> */
    private const UNITS = ['kg', 'gram', 'piece', 'liter', 'package', 'box', 'bundle', 'meter'];

    /** @var list<string> */
    private const POLICIES = ['allow_similar_substitution', 'contact_before_substitution', 'remove_if_unavailable'];

    /** @var list<string> */
    private const STATUSES = ['pending', 'awaiting_customer', 'purchased', 'removed'];

    /** @var list<string> */
    private const REMOVED_REASONS = [
        'unavailable', 'customer_rejected', 'approval_expired', 'customer_removed', 'operator_removed', 'order_cancelled',
    ];

    public function up(): void
    {
        Schema::create('order_items', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('order_id');
            $table->uuid('product_id');
            $table->string('product_name_uz_snapshot', 160);
            $table->string('product_name_ru_snapshot', 160);
            $table->string('unit_code_snapshot', 16);
            $table->string('price_mode_snapshot', 16);
            $table->bigInteger('market_price_uzs_snapshot');
            $table->bigInteger('customer_unit_price_uzs_snapshot');
            $table->decimal('markup_percent_snapshot', 5, 2);
            $table->decimal('ordered_quantity', 18, 3);
            $table->decimal('purchased_quantity', 18, 3)->nullable();
            $table->decimal('billable_quantity', 18, 3)->default(0);
            $table->string('customer_note_snapshot', 300)->nullable();
            $table->string('substitution_policy_snapshot', 40);
            $table->string('status', 24)->default('pending');
            $table->decimal('approved_quantity_cap', 18, 3)->nullable();
            $table->bigInteger('approved_unit_price_ceiling_uzs')->nullable();
            $table->uuid('fulfilled_product_id')->nullable();
            $table->string('fulfilled_product_name_uz_snapshot', 160)->nullable();
            $table->string('fulfilled_product_name_ru_snapshot', 160)->nullable();
            $table->string('fulfilled_unit_code_snapshot', 16)->nullable();
            $table->string('substitution_resolution', 16)->nullable();
            $table->bigInteger('actual_market_price_uzs')->nullable();
            $table->bigInteger('billable_unit_price_uzs')->nullable();
            $table->bigInteger('line_total_uzs')->nullable();
            $table->string('removed_reason_code', 40)->nullable();
            $table->timestampTz('removed_at')->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->index(['order_id', 'status']);
            $table->index('fulfilled_product_id');
        });

        Schema::table('order_items', function (Blueprint $table): void {
            $table->foreign('order_id')->references('id')->on('orders')->restrictOnDelete();
            $table->foreign('product_id')->references('id')->on('products')->restrictOnDelete();
            $table->foreign('fulfilled_product_id')->references('id')->on('products')->restrictOnDelete();
        });

        $this->check('order_items_unit_code_check', sprintf('unit_code_snapshot in (%s)', $this->quoted(self::UNITS)));
        $this->check(
            'order_items_fulfilled_unit_code_check',
            sprintf('fulfilled_unit_code_snapshot is null or fulfilled_unit_code_snapshot in (%s)', $this->quoted(self::UNITS))
        );
        $this->check('order_items_price_mode_check', "price_mode_snapshot in ('fixed', 'estimate')");
        $this->check('order_items_substitution_policy_check', sprintf('substitution_policy_snapshot in (%s)', $this->quoted(self::POLICIES)));
        $this->check('order_items_status_check', sprintf('status in (%s)', $this->quoted(self::STATUSES)));
        $this->check('order_items_substitution_resolution_check', "substitution_resolution is null or substitution_resolution in ('automatic', 'approved')");
        $this->check(
            'order_items_removed_reason_check',
            sprintf('removed_reason_code is null or removed_reason_code in (%s)', $this->quoted(self::REMOVED_REASONS))
        );
        $this->check('order_items_names_not_blank_check', 'length(btrim(product_name_uz_snapshot)) > 0 and length(btrim(product_name_ru_snapshot)) > 0');
        $this->check(
            'order_items_prices_check',
            'market_price_uzs_snapshot > 0 and customer_unit_price_uzs_snapshot > 0 and markup_percent_snapshot >= 0'
            .' and (approved_unit_price_ceiling_uzs is null or approved_unit_price_ceiling_uzs > 0)'
            .' and (actual_market_price_uzs is null or actual_market_price_uzs > 0)'
            .' and (billable_unit_price_uzs is null or billable_unit_price_uzs > 0)'
            .' and (line_total_uzs is null or line_total_uzs >= 0)'
        );
        $this->check(
            'order_items_quantities_check',
            'ordered_quantity > 0 and (purchased_quantity is null or purchased_quantity > 0)'
            .' and billable_quantity >= 0 and billable_quantity <= ordered_quantity'
            .' and (approved_quantity_cap is null or (approved_quantity_cap > 0 and approved_quantity_cap < ordered_quantity))'
            .' and (approved_quantity_cap is null or billable_quantity <= approved_quantity_cap)'
        );
        $this->check(
            'order_items_fulfilled_product_check',
            '(fulfilled_product_id is null) = (fulfilled_product_name_uz_snapshot is null)'
            .' and (fulfilled_product_id is null) = (fulfilled_product_name_ru_snapshot is null)'
            .' and (fulfilled_product_id is null) = (fulfilled_unit_code_snapshot is null)'
        );
        $this->check(
            'order_items_open_check',
            "status not in ('pending', 'awaiting_customer') or (billable_quantity = 0 and line_total_uzs is null and billable_unit_price_uzs is null)"
        );
        $this->check(
            'order_items_purchased_check',
            "status <> 'purchased' or (purchased_quantity is not null and billable_quantity > 0"
            .' and purchased_quantity >= billable_quantity and billable_unit_price_uzs is not null'
            .' and line_total_uzs is not null and fulfilled_product_id is not null)'
        );
        // BR-MONEY-003, where both factors are stored: round() on a
        // non-negative numeric is half-up to 1 UZS.
        $this->check(
            'order_items_line_total_check',
            'line_total_uzs is null or billable_unit_price_uzs is null'
            .' or line_total_uzs = round(billable_unit_price_uzs * billable_quantity)'
        );
        // BR-PRICE-002: a fixed line bought as itself is billed at its snapshot.
        $this->check(
            'order_items_fixed_price_check',
            "status <> 'purchased' or price_mode_snapshot <> 'fixed' or fulfilled_product_id <> product_id"
            .' or billable_unit_price_uzs = customer_unit_price_uzs_snapshot'
        );
        $this->check(
            'order_items_removed_check',
            "(status = 'removed') = (removed_reason_code is not null) and (status = 'removed') = (removed_at is not null)"
            ." and (status <> 'removed' or (billable_quantity = 0 and line_total_uzs is not null and line_total_uzs = 0))"
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('order_items');
    }

    private function check(string $name, string $expression): void
    {
        DB::statement("alter table order_items add constraint {$name} check ({$expression})");
    }

    /**
     * @param  list<string>  $values
     */
    private function quoted(array $values): string
    {
        return implode(', ', array_map(static fn (string $value): string => "'{$value}'", $values));
    }
};
