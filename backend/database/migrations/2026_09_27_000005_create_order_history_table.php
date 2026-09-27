<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `order_history`, as `docs/08-database.md` Section 15 names it: append-only,
 * with `details` for the structured facts an event needs to stay explainable —
 * an edit's before and after, an assignment and its self-order flag (`DL-37`
 * (9), (14)).
 *
 * Append-only is held by a trigger, not only by convention: `docs/05` Section
 * 22 says no path bypasses this history, and a row that could be rewritten
 * would not be history.
 */
return new class extends Migration
{
    /** @var list<string> */
    private const EVENTS = [
        'status_changed', 'edited', 'payment_method_switched', 'price_corrected',
        'shopper_assigned', 'shopper_reassigned', 'courier_assigned', 'courier_reassigned',
        'delivery_failed', 'approval_requested', 'approval_decided', 'approval_expired', 'approval_resolved',
    ];

    /** @var list<string> */
    private const STATUSES = [
        'new', 'shopping_assigned', 'shopping', 'final_payment_pending', 'ready_for_delivery',
        'delivery_assigned', 'on_the_way', 'completed', 'cancelled',
    ];

    /** @var list<string> */
    private const CANCELLATION_REASONS = [
        'customer_cancelled', 'cancellation_request_approved', 'unpaid_online',
        'no_items_purchased', 'delivery_failed', 'system',
    ];

    public function up(): void
    {
        Schema::create('order_history', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('order_id');
            $table->string('event_type', 40);
            $table->string('from_status', 32)->nullable();
            $table->string('to_status', 32)->nullable();
            $table->string('actor_type', 24);
            $table->uuid('actor_user_id')->nullable();
            $table->string('reason_code', 40)->nullable();
            $table->text('note')->nullable();
            $table->jsonb('details')->nullable();
            $table->timestampTz('created_at');

            $table->index(['order_id', 'created_at']);
        });

        Schema::table('order_history', function (Blueprint $table): void {
            $table->foreign('order_id')->references('id')->on('orders')->restrictOnDelete();
            $table->foreign('actor_user_id')->references('id')->on('users')->restrictOnDelete();
        });

        $this->check('order_history_event_type_check', sprintf('event_type in (%s)', $this->quoted(self::EVENTS)));
        $this->check(
            'order_history_statuses_check',
            sprintf(
                '(from_status is null or from_status in (%1$s)) and (to_status is null or to_status in (%1$s))',
                $this->quoted(self::STATUSES)
            )
        );
        $this->check('order_history_actor_type_check', "actor_type in ('user', 'system', 'payment_provider')");
        $this->check('order_history_actor_user_check', "(actor_type = 'user') = (actor_user_id is not null)");
        $this->check(
            'order_history_reason_code_check',
            sprintf('reason_code is null or reason_code in (%s)', $this->quoted(self::CANCELLATION_REASONS))
        );
        $this->check('order_history_details_object_check', "details is null or jsonb_typeof(details) = 'object'");

        DB::unprepared(<<<'SQL'
            create or replace function order_history_append_only() returns trigger language plpgsql as $$
            begin
                raise exception 'order_history is append-only';
            end;
            $$;

            create trigger order_history_append_only
                before update or delete on order_history
                for each row execute function order_history_append_only();
            SQL);
    }

    public function down(): void
    {
        Schema::dropIfExists('order_history');
        DB::statement('drop function if exists order_history_append_only()');
    }

    private function check(string $name, string $expression): void
    {
        DB::statement("alter table order_history add constraint {$name} check ({$expression})");
    }

    /**
     * @param  list<string>  $values
     */
    private function quoted(array $values): string
    {
        return implode(', ', array_map(static fn (string $value): string => "'{$value}'", $values));
    }
};
