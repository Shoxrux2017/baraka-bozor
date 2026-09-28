<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `payments`, as `docs/08-database.md` Section 21 names it, created whole
 * although Wave 3 writes only the cash row a delivery records (`DL-54` (2)):
 * Wave 5 then adds its attempts and refunds beside a table it need not
 * reshape.
 *
 * One live payment per order. A cash payment exists only as paid, recorded by
 * the Courier at handover with the amount (`BR-PAY-003`), and names no
 * provider; an online payment is never recorded by a person (`BR-PAY-004`).
 * A paid or cancelled payment says when.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('payments', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('order_id');
            $table->string('method', 16);
            $table->string('provider', 16)->nullable();
            $table->bigInteger('amount_uzs');
            $table->string('status', 16);
            $table->timestampTz('attention_at')->nullable();
            $table->timestampTz('paid_at')->nullable();
            $table->timestampTz('cancelled_at')->nullable();
            $table->uuid('recorded_by_user_id')->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');
        });

        Schema::table('payments', function (Blueprint $table): void {
            $table->foreign('order_id')->references('id')->on('orders')->restrictOnDelete();
            $table->foreign('recorded_by_user_id')->references('id')->on('users')->restrictOnDelete();
        });

        $this->check('payments_method_check', "method in ('cash', 'online')");
        $this->check('payments_provider_check', "provider is null or provider in ('payme', 'click', 'paynet', 'xazna')");
        $this->check('payments_status_check', "status in ('unpaid', 'pending', 'paid', 'cancelled')");
        $this->check('payments_amount_check', 'amount_uzs > 0');
        $this->check(
            'payments_cash_check',
            "method <> 'cash' or (status = 'paid' and provider is null and recorded_by_user_id is not null and attention_at is null)"
        );
        $this->check('payments_online_check', "method <> 'online' or recorded_by_user_id is null");
        $this->check('payments_paid_check', "(status = 'paid') = (paid_at is not null)");
        $this->check('payments_cancelled_check', "(status = 'cancelled') = (cancelled_at is not null)");

        DB::statement("create unique index payments_order_live_unique on payments (order_id) where status <> 'cancelled'");
        DB::statement('create index payments_order_id_index on payments (order_id)');
    }

    public function down(): void
    {
        Schema::dropIfExists('payments');
    }

    private function check(string $name, string $expression): void
    {
        DB::statement("alter table payments add constraint {$name} check ({$expression})");
    }
};
