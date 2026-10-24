<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `notification_deliveries`, as `docs/08-database.md` Section 26 names it: one
 * row per push per device, or one `skipped` row without a device when nothing
 * is sent. `push_device_id` is `ON DELETE SET NULL`, so erasing a Customer,
 * which deletes the devices, is never blocked by a delivery row (`DL-104`).
 */
return new class extends Migration
{
    /** @var list<string> */
    private const TYPES = [
        'order_accepted', 'shopping_assigned', 'approval_required', 'approval_answered',
        'shopping_completed', 'payment_required', 'courier_started', 'order_delivered',
        'order_cancelled', 'shopping_order_cancelled', 'delivery_assigned', 'delivery_cancelled',
        'cancellation_rejected',
    ];

    /** @var list<string> */
    private const STATUSES = ['queued', 'sent', 'failed', 'skipped'];

    public function up(): void
    {
        Schema::create('notification_deliveries', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('user_id');
            $table->uuid('push_device_id')->nullable();
            $table->uuid('order_id')->nullable();
            $table->uuid('approval_id')->nullable();
            $table->string('type', 40);
            $table->string('status', 16);
            $table->integer('attempt_count')->default(0);
            $table->timestampTz('sent_at')->nullable();
            $table->string('last_error_code', 64)->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->index(['user_id', 'created_at']);
            $table->index(['status', 'created_at']);
        });

        Schema::table('notification_deliveries', function (Blueprint $table): void {
            $table->foreign('user_id')->references('id')->on('users')->restrictOnDelete();
            $table->foreign('push_device_id')->references('id')->on('push_devices')->nullOnDelete();
            $table->foreign('order_id')->references('id')->on('orders')->restrictOnDelete();
            $table->foreign('approval_id')->references('id')->on('customer_approvals')->restrictOnDelete();
        });

        $this->check('notification_deliveries_type_check', sprintf('type in (%s)', $this->quoted(self::TYPES)));
        $this->check('notification_deliveries_status_check', sprintf('status in (%s)', $this->quoted(self::STATUSES)));
        $this->check('notification_deliveries_attempt_count_check', 'attempt_count >= 0');
    }

    public function down(): void
    {
        Schema::dropIfExists('notification_deliveries');
    }

    private function check(string $name, string $expression): void
    {
        DB::statement("alter table notification_deliveries add constraint {$name} check ({$expression})");
    }

    /**
     * @param  list<string>  $values
     */
    private function quoted(array $values): string
    {
        return implode(', ', array_map(static fn (string $value): string => "'{$value}'", $values));
    }
};
