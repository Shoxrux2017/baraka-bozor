<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `order_courier_assignments`, as `docs/08-database.md` Section 17 names it.
 *
 * One current assignment per order is a database rule (`BR-CON-002`), as for
 * the Shopper's. A delivery start follows acceptance and carries the instant
 * the order becomes late (`BR-DEL-002`); a failed delivery says why
 * (`BR-DEL-003`), with a note when the reason is `other`.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('order_courier_assignments', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('order_id');
            $table->uuid('courier_id');
            $table->uuid('assigned_by_user_id');
            $table->boolean('is_self_order');
            $table->timestampTz('assigned_at');
            $table->timestampTz('accepted_at')->nullable();
            $table->timestampTz('delivery_started_at')->nullable();
            $table->timestampTz('delay_at')->nullable();
            $table->timestampTz('completed_at')->nullable();
            $table->timestampTz('ended_at')->nullable();
            $table->string('ended_reason', 24)->nullable();
            $table->string('failed_reason_code', 24)->nullable();
            $table->string('failed_note', 300)->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');
        });

        Schema::table('order_courier_assignments', function (Blueprint $table): void {
            $table->foreign('order_id')->references('id')->on('orders')->restrictOnDelete();
            $table->foreign('courier_id')->references('id')->on('users')->restrictOnDelete();
            $table->foreign('assigned_by_user_id')->references('id')->on('users')->restrictOnDelete();
        });

        $this->check(
            'order_courier_assignments_ended_reason_check',
            "ended_reason is null or ended_reason in ('completed', 'reassigned', 'delivery_failed', 'order_cancelled')"
        );
        $this->check('order_courier_assignments_ended_check', '(ended_at is null) = (ended_reason is null)');
        $this->check('order_courier_assignments_started_check', 'delivery_started_at is null or accepted_at is not null');
        $this->check(
            'order_courier_assignments_delay_check',
            '(delivery_started_at is null) = (delay_at is null) and (delay_at is null or delay_at > delivery_started_at)'
        );
        $this->check('order_courier_assignments_completed_check', 'completed_at is null or delivery_started_at is not null');
        $this->check(
            'order_courier_assignments_completed_end_check',
            "ended_reason is null or ended_reason <> 'completed' or completed_at is not null"
        );
        $this->check(
            'order_courier_assignments_failed_reason_check',
            "failed_reason_code is null or failed_reason_code in ('no_answer', 'refused', 'wrong_address', 'other')"
        );
        // A failure is a delivery that set off and came back, with its reason;
        // no other end carries one.
        $this->check(
            'order_courier_assignments_failed_check',
            "(coalesce(ended_reason, '') = 'delivery_failed') = (failed_reason_code is not null)"
            ." and (coalesce(ended_reason, '') <> 'delivery_failed' or delivery_started_at is not null)"
        );
        $this->check(
            'order_courier_assignments_failed_note_check',
            'failed_note is null or (failed_reason_code is not null and length(btrim(failed_note)) > 0)'
        );
        $this->check(
            'order_courier_assignments_other_note_check',
            "failed_reason_code is null or failed_reason_code <> 'other' or failed_note is not null"
        );

        DB::statement(
            'create unique index order_courier_assignments_order_current_unique on order_courier_assignments (order_id) where ended_at is null'
        );
        DB::statement(
            'create index order_courier_assignments_courier_current_index on order_courier_assignments (courier_id) where ended_at is null'
        );
        DB::statement('create index order_courier_assignments_order_id_index on order_courier_assignments (order_id)');
        DB::statement('create index order_courier_assignments_delay_at_index on order_courier_assignments (delay_at)');
    }

    public function down(): void
    {
        Schema::dropIfExists('order_courier_assignments');
    }

    private function check(string $name, string $expression): void
    {
        DB::statement("alter table order_courier_assignments add constraint {$name} check ({$expression})");
    }
};
