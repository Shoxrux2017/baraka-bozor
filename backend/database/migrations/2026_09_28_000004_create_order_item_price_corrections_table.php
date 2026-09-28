<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `order_item_price_corrections`, as `docs/08-database.md` Section 19 names
 * it: the Admin's corrections of a recorded purchase price (`BR-PRICE-006`,
 * `DL-54` (18)), each with its reason, the prices before and after, and who
 * made it.
 *
 * Append-only by a trigger, like `order_history` (`DL-38` (4)): a correction
 * that could be rewritten would not be an audit. A correction changes the
 * price; the current price again writes nothing (`DL-54` (18)).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('order_item_price_corrections', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('order_item_id');
            $table->bigInteger('old_actual_market_price_uzs');
            $table->bigInteger('new_actual_market_price_uzs');
            $table->bigInteger('old_billable_unit_price_uzs');
            $table->bigInteger('new_billable_unit_price_uzs');
            $table->uuid('corrected_by_user_id');
            $table->string('reason', 300);
            $table->timestampTz('created_at');

            $table->index(['order_item_id', 'created_at']);
        });

        Schema::table('order_item_price_corrections', function (Blueprint $table): void {
            $table->foreign('order_item_id')->references('id')->on('order_items')->restrictOnDelete();
            $table->foreign('corrected_by_user_id')->references('id')->on('users')->restrictOnDelete();
        });

        $this->check(
            'order_item_price_corrections_prices_check',
            'old_actual_market_price_uzs > 0 and new_actual_market_price_uzs > 0'
            .' and old_billable_unit_price_uzs > 0 and new_billable_unit_price_uzs > 0'
        );
        $this->check('order_item_price_corrections_changed_check', 'new_actual_market_price_uzs <> old_actual_market_price_uzs');
        $this->check('order_item_price_corrections_reason_check', 'length(btrim(reason)) > 0');

        DB::unprepared(<<<'SQL'
            create or replace function order_item_price_corrections_append_only() returns trigger language plpgsql as $$
            begin
                raise exception 'order_item_price_corrections is append-only';
            end;
            $$;

            create trigger order_item_price_corrections_append_only
                before update or delete on order_item_price_corrections
                for each row execute function order_item_price_corrections_append_only();
            SQL);
    }

    public function down(): void
    {
        Schema::dropIfExists('order_item_price_corrections');
        DB::statement('drop function if exists order_item_price_corrections_append_only()');
    }

    private function check(string $name, string $expression): void
    {
        DB::statement("alter table order_item_price_corrections add constraint {$name} check ({$expression})");
    }
};
