<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `idempotency_keys`, as `docs/08-database.md` Section 27 names it, with the
 * attempt token of `DL-37` (5).
 *
 * A key is scoped to its actor and operation. `processing` holds a lease; the
 * attempt that owns the row is named by `attempt_token`, renewed by every begin
 * and takeover, so an attempt that outran its lease can neither complete over
 * nor delete the record of the one that took over.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('idempotency_keys', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('actor_user_id');
            $table->string('operation', 80);
            $table->uuid('idempotency_key');
            $table->char('request_hash', 64);
            $table->string('state', 16);
            $table->uuid('attempt_token');
            $table->timestampTz('lease_expires_at');
            $table->string('resource_type', 40)->nullable();
            $table->uuid('resource_id')->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('completed_at')->nullable();

            $table->unique(['actor_user_id', 'operation', 'idempotency_key']);
            $table->index('completed_at');
        });

        Schema::table('idempotency_keys', function (Blueprint $table): void {
            $table->foreign('actor_user_id')->references('id')->on('users')->restrictOnDelete();
        });

        $this->check('idempotency_keys_state_check', "state in ('processing', 'completed')");
        $this->check(
            'idempotency_keys_completed_check',
            "(state = 'completed') = (completed_at is not null)"
            ." and (state <> 'completed' or (resource_type is not null and resource_id is not null))"
        );
        $this->check('idempotency_keys_request_hash_check', "request_hash ~ '^[0-9a-f]{64}$'");
        $this->check('idempotency_keys_operation_not_blank_check', 'length(btrim(operation)) > 0');
    }

    public function down(): void
    {
        Schema::dropIfExists('idempotency_keys');
    }

    private function check(string $name, string $expression): void
    {
        DB::statement("alter table idempotency_keys add constraint {$name} check ({$expression})");
    }
};
