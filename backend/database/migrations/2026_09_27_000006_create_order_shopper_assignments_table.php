<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `order_shopper_assignments`, as `docs/08-database.md` Section 16 names it.
 *
 * One current assignment per order is a database rule (`BR-CON-002`): two
 * Operators assigning at once cannot both succeed. An assignment ends rather
 * than being deleted, so the history of who held an order stays whole.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('order_shopper_assignments', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('order_id');
            $table->uuid('shopper_id');
            $table->uuid('assigned_by_user_id');
            $table->boolean('is_self_order');
            $table->timestampTz('assigned_at');
            $table->timestampTz('accepted_at')->nullable();
            $table->timestampTz('started_at')->nullable();
            $table->timestampTz('completed_at')->nullable();
            $table->timestampTz('ended_at')->nullable();
            $table->string('ended_reason', 24)->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');
        });

        Schema::table('order_shopper_assignments', function (Blueprint $table): void {
            $table->foreign('order_id')->references('id')->on('orders')->restrictOnDelete();
            $table->foreign('shopper_id')->references('id')->on('users')->restrictOnDelete();
            $table->foreign('assigned_by_user_id')->references('id')->on('users')->restrictOnDelete();
        });

        $this->check('order_shopper_assignments_ended_reason_check', "ended_reason is null or ended_reason in ('completed', 'reassigned', 'order_cancelled')");
        $this->check('order_shopper_assignments_ended_check', '(ended_at is null) = (ended_reason is null)');
        $this->check('order_shopper_assignments_started_check', 'started_at is null or accepted_at is not null');
        $this->check('order_shopper_assignments_completed_check', 'completed_at is null or started_at is not null');
        $this->check(
            'order_shopper_assignments_completed_end_check',
            "ended_reason is null or ended_reason <> 'completed' or completed_at is not null"
        );

        DB::statement(
            'create unique index order_shopper_assignments_order_current_unique on order_shopper_assignments (order_id) where ended_at is null'
        );
        DB::statement(
            'create index order_shopper_assignments_shopper_current_index on order_shopper_assignments (shopper_id) where ended_at is null'
        );
        // Every assignment of an order, ended ones included, for the order's
        // history on the board; the partial index above covers only the current.
        DB::statement('create index order_shopper_assignments_order_id_index on order_shopper_assignments (order_id)');
    }

    public function down(): void
    {
        Schema::dropIfExists('order_shopper_assignments');
    }

    private function check(string $name, string $expression): void
    {
        DB::statement("alter table order_shopper_assignments add constraint {$name} check ({$expression})");
    }
};
