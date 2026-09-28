<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `customer_approvals`, as `docs/08-database.md` Section 18 names it, with the
 * status `cancelled` for an approval whose order is cancelled (`DL-54` (8)).
 *
 * The proposal is what the Customer decides on (`BR-APP-005`), so its shape
 * is held per type: a price question carries its prices, and names the
 * replacement when it is about one (`DL-54` (5)); a substitution carries its
 * replacement and prices; a smaller quantity carries only the quantity. Each
 * status holds the columns it implies: nobody resolved a pending approval; the
 * Customer resolved an approved or rejected one; an expired one waits for an
 * Operator to remove the line; a cancelled one ended with its order.
 */
return new class extends Migration
{
    /** @var list<string> */
    private const UNITS = ['kg', 'gram', 'piece', 'liter', 'package', 'box', 'bundle', 'meter'];

    public function up(): void
    {
        Schema::create('customer_approvals', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('order_id');
            $table->uuid('order_item_id');
            $table->string('type', 24);
            $table->string('status', 16);
            $table->uuid('requested_by_user_id');
            $table->bigInteger('proposed_customer_unit_price_uzs')->nullable();
            $table->bigInteger('proposed_actual_market_price_uzs')->nullable();
            $table->decimal('proposed_quantity', 18, 3)->nullable();
            $table->uuid('replacement_product_id')->nullable();
            $table->string('replacement_name_uz_snapshot', 160)->nullable();
            $table->string('replacement_name_ru_snapshot', 160)->nullable();
            $table->string('replacement_unit_code_snapshot', 16)->nullable();
            $table->string('request_note', 300)->nullable();
            $table->timestampTz('attention_at');
            $table->timestampTz('expires_at');
            $table->uuid('resolved_by_user_id')->nullable();
            $table->timestampTz('resolved_at')->nullable();
            $table->string('resolution', 16)->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');
        });

        Schema::table('customer_approvals', function (Blueprint $table): void {
            $table->foreign('order_id')->references('id')->on('orders')->restrictOnDelete();
            $table->foreign('order_item_id')->references('id')->on('order_items')->restrictOnDelete();
            $table->foreign('requested_by_user_id')->references('id')->on('users')->restrictOnDelete();
            $table->foreign('replacement_product_id')->references('id')->on('products')->restrictOnDelete();
            $table->foreign('resolved_by_user_id')->references('id')->on('users')->restrictOnDelete();
        });

        $this->check('customer_approvals_type_check', "type in ('price_over_tolerance', 'substitution', 'reduced_quantity')");
        $this->check('customer_approvals_status_check', "status in ('pending', 'approved', 'rejected', 'expired', 'cancelled')");
        $this->check('customer_approvals_resolution_check', "resolution is null or resolution in ('approved', 'rejected', 'remove_item')");
        $this->check(
            'customer_approvals_proposed_values_check',
            '(proposed_customer_unit_price_uzs is null or proposed_customer_unit_price_uzs > 0)'
            .' and (proposed_actual_market_price_uzs is null or proposed_actual_market_price_uzs > 0)'
            .' and (proposed_quantity is null or proposed_quantity > 0)'
        );
        $this->check(
            'customer_approvals_replacement_check',
            '(replacement_product_id is null) = (replacement_name_uz_snapshot is null)'
            .' and (replacement_product_id is null) = (replacement_name_ru_snapshot is null)'
            .' and (replacement_product_id is null) = (replacement_unit_code_snapshot is null)'
            .' and (replacement_unit_code_snapshot is null or replacement_unit_code_snapshot in ('.$this->quoted(self::UNITS).'))'
        );
        $this->check(
            'customer_approvals_proposal_check',
            "(type <> 'price_over_tolerance' or (proposed_customer_unit_price_uzs is not null"
            .' and proposed_actual_market_price_uzs is not null and proposed_quantity is null))'
            ." and (type <> 'substitution' or (replacement_product_id is not null"
            .' and proposed_customer_unit_price_uzs is not null and proposed_actual_market_price_uzs is not null'
            .' and proposed_quantity is null))'
            ." and (type <> 'reduced_quantity' or (proposed_quantity is not null and proposed_customer_unit_price_uzs is null"
            .' and proposed_actual_market_price_uzs is null and replacement_product_id is null))'
        );
        $this->check('customer_approvals_timers_check', 'attention_at < expires_at');
        $this->check('customer_approvals_note_check', 'request_note is null or length(btrim(request_note)) > 0');
        $this->check(
            'customer_approvals_pending_check',
            "status <> 'pending' or (resolution is null and resolved_by_user_id is null and resolved_at is null)"
        );
        $this->check(
            'customer_approvals_decided_check',
            "status not in ('approved', 'rejected') or (resolution is not null and resolution = status"
            .' and resolved_by_user_id is not null and resolved_at is not null)'
        );
        $this->check(
            'customer_approvals_expired_check',
            "status <> 'expired' or (resolution is null and resolved_by_user_id is null and resolved_at is null)"
            ." or (resolution is not null and resolution = 'remove_item' and resolved_by_user_id is not null and resolved_at is not null)"
        );
        $this->check('customer_approvals_cancelled_check', "status <> 'cancelled' or (resolution is null and resolved_at is not null)");

        DB::statement(
            "create unique index customer_approvals_item_pending_unique on customer_approvals (order_item_id) where status = 'pending'"
        );
        DB::statement('create index customer_approvals_order_id_status_index on customer_approvals (order_id, status)');
        DB::statement('create index customer_approvals_status_attention_at_index on customer_approvals (status, attention_at)');
        DB::statement('create index customer_approvals_status_expires_at_index on customer_approvals (status, expires_at)');
    }

    public function down(): void
    {
        Schema::dropIfExists('customer_approvals');
    }

    private function check(string $name, string $expression): void
    {
        DB::statement("alter table customer_approvals add constraint {$name} check ({$expression})");
    }

    /**
     * @param  list<string>  $values
     */
    private function quoted(array $values): string
    {
        return implode(', ', array_map(static fn (string $value): string => "'{$value}'", $values));
    }
};
