<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `idempotency_keys.response` (`DL-91` item 3, `docs/08` Section 27): the
 * answer of an operation that produces no single resource, such as a reorder.
 * A completed key then names a resource or holds a response.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('idempotency_keys', function ($table): void {
            $table->jsonb('response')->nullable();
        });

        DB::statement('alter table idempotency_keys drop constraint idempotency_keys_completed_check');
        $this->check(
            'idempotency_keys_completed_check',
            "(state = 'completed') = (completed_at is not null)"
            ." and (state <> 'completed' or (resource_type is not null and resource_id is not null) or response is not null)"
        );
    }

    public function down(): void
    {
        DB::statement('delete from idempotency_keys where response is not null');
        DB::statement('alter table idempotency_keys drop constraint idempotency_keys_completed_check');
        $this->check(
            'idempotency_keys_completed_check',
            "(state = 'completed') = (completed_at is not null)"
            ." and (state <> 'completed' or (resource_type is not null and resource_id is not null))"
        );
        Schema::table('idempotency_keys', function ($table): void {
            $table->dropColumn('response');
        });
    }

    private function check(string $name, string $expression): void
    {
        DB::statement("alter table idempotency_keys add constraint {$name} check ({$expression})");
    }
};
