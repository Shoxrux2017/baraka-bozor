<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `order_cancellation_requests`, as `docs/08-database.md` Section 20 names it,
 * with the status `closed` for a request still pending when its order was
 * cancelled another way (`DL-54` (12)).
 *
 * At most one pending request per order (`BR-CAN-002`). An Operator's decision
 * names who decided and when; a closed request only when, since nobody decided
 * it. The Customer's reason is required (`DL-37` (13)).
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('order_cancellation_requests', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('order_id');
            $table->string('origin', 16);
            $table->uuid('requested_by_user_id');
            $table->string('status', 16);
            $table->string('reason', 300);
            $table->uuid('resolved_by_user_id')->nullable();
            $table->string('resolution_note', 300)->nullable();
            $table->timestampTz('resolved_at')->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');
        });

        Schema::table('order_cancellation_requests', function (Blueprint $table): void {
            $table->foreign('order_id')->references('id')->on('orders')->restrictOnDelete();
            $table->foreign('requested_by_user_id')->references('id')->on('users')->restrictOnDelete();
            $table->foreign('resolved_by_user_id')->references('id')->on('users')->restrictOnDelete();
        });

        $this->check('order_cancellation_requests_origin_check', "origin in ('customer', 'staff')");
        $this->check('order_cancellation_requests_status_check', "status in ('pending', 'approved', 'rejected', 'closed')");
        $this->check('order_cancellation_requests_reason_check', 'length(btrim(reason)) > 0');
        $this->check(
            'order_cancellation_requests_note_check',
            'resolution_note is null or (resolved_by_user_id is not null and length(btrim(resolution_note)) > 0)'
        );
        $this->check(
            'order_cancellation_requests_pending_check',
            "status <> 'pending' or (resolved_by_user_id is null and resolved_at is null)"
        );
        $this->check(
            'order_cancellation_requests_decided_check',
            "status not in ('approved', 'rejected') or (resolved_by_user_id is not null and resolved_at is not null)"
        );
        $this->check(
            'order_cancellation_requests_closed_check',
            "status <> 'closed' or (resolved_by_user_id is null and resolved_at is not null)"
        );

        DB::statement(
            "create unique index order_cancellation_requests_order_pending_unique on order_cancellation_requests (order_id) where status = 'pending'"
        );
        DB::statement('create index order_cancellation_requests_order_id_index on order_cancellation_requests (order_id)');
        DB::statement('create index order_cancellation_requests_status_created_at_index on order_cancellation_requests (status, created_at)');
    }

    public function down(): void
    {
        Schema::dropIfExists('order_cancellation_requests');
    }

    private function check(string $name, string $expression): void
    {
        DB::statement("alter table order_cancellation_requests add constraint {$name} check ({$expression})");
    }
};
