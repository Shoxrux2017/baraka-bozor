<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `push_devices`, as `docs/08-database.md` Section 25 names it: one row per
 * token per account. A phone that holds a Customer account and a Staff account
 * registers its token once for each (interview 7.0), so the unique key is the
 * pair, not the token alone. A device is revoked rather than deleted and comes
 * back when it registers again (`DL-17`).
 */
return new class extends Migration
{
    /** @var list<string> */
    private const PLATFORMS = ['android', 'ios', 'web'];

    public function up(): void
    {
        Schema::create('push_devices', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('user_id');
            $table->string('platform', 16);
            $table->string('push_token', 512);
            $table->timestampTz('last_seen_at')->nullable();
            $table->timestampTz('revoked_at')->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(['push_token', 'user_id']);
        });

        Schema::table('push_devices', function (Blueprint $table): void {
            $table->foreign('user_id')
                ->references('id')
                ->on('users')
                ->restrictOnDelete();
        });

        DB::statement(sprintf(
            'alter table push_devices add constraint push_devices_platform_check check (platform in (%s))',
            implode(', ', array_map(static fn (string $value): string => "'{$value}'", self::PLATFORMS))
        ));
        DB::statement(
            'alter table push_devices add constraint push_devices_push_token_not_blank_check check (length(btrim(push_token)) > 0)'
        );

        // The live devices of an account, which is what a notification job asks
        // for; revoked rows stay out of the index and out of the way.
        DB::statement('create index push_devices_user_live_index on push_devices (user_id) where revoked_at is null');
    }

    public function down(): void
    {
        Schema::dropIfExists('push_devices');
    }
};
