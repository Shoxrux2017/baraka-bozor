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
 *
 * The line belongs to the approval's order, held by a foreign key to the
 * pair `(id, order_id)` of `order_items`. The proposal is immutable after
 * creation (`BR-APP-001`), and a trigger holds it: an update may change only
 * the resolution, only of a pending approval or of an expired one an
 * Operator resolves, and no approval is deleted (`DL-55` (2)).
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

        // The target of the foreign key that keeps a line inside its order.
        DB::statement('create unique index order_items_id_order_id_unique on order_items (id, order_id)');

        Schema::table('customer_approvals', function (Blueprint $table): void {
            $table->foreign('order_id')->references('id')->on('orders')->restrictOnDelete();
            $table->foreign('order_item_id')->references('id')->on('order_items')->restrictOnDelete();
            $table->foreign(['order_item_id', 'order_id'], 'customer_approvals_item_in_order_foreign')
                ->references(['id', 'order_id'])->on('order_items')->restrictOnDelete();
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

        DB::unprepared(<<<'SQL'
            create or replace function customer_approvals_guard() returns trigger language plpgsql as $$
            begin
                if tg_op = 'DELETE' then
                    raise exception 'customer_approvals are never deleted';
                end if;
                if (new.id, new.order_id, new.order_item_id, new.type, new.requested_by_user_id,
                    new.proposed_customer_unit_price_uzs, new.proposed_actual_market_price_uzs, new.proposed_quantity,
                    new.replacement_product_id, new.replacement_name_uz_snapshot, new.replacement_name_ru_snapshot,
                    new.replacement_unit_code_snapshot, new.request_note, new.attention_at, new.expires_at, new.created_at)
                   is distinct from
                   (old.id, old.order_id, old.order_item_id, old.type, old.requested_by_user_id,
                    old.proposed_customer_unit_price_uzs, old.proposed_actual_market_price_uzs, old.proposed_quantity,
                    old.replacement_product_id, old.replacement_name_uz_snapshot, old.replacement_name_ru_snapshot,
                    old.replacement_unit_code_snapshot, old.request_note, old.attention_at, old.expires_at, old.created_at) then
                    raise exception 'a customer_approvals proposal is immutable';
                end if;
                if not (old.status = 'pending' or (old.status = 'expired' and old.resolution is null and new.status = 'expired')) then
                    raise exception 'a resolved customer_approvals row never changes';
                end if;
                return new;
            end;
            $$;

            create trigger customer_approvals_guard
                before update or delete on customer_approvals
                for each row execute function customer_approvals_guard();
            SQL);
    }

    public function down(): void
    {
        Schema::dropIfExists('customer_approvals');
        DB::statement('drop function if exists customer_approvals_guard()');
        DB::statement('drop index if exists order_items_id_order_id_unique');
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
