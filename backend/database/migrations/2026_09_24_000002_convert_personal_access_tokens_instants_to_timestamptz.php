<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * The published Sanctum migration declared its instants as `timestamp without
 * time zone`. `docs/08-database.md` Section 1 requires `timestamptz`, and
 * `last_used_at` is now authoritative: the sliding 30-day token lifetime is
 * measured from it. A forward `ALTER` rather than an edit of the delivered
 * migration, which `backend/AGENTS.md` Section 6 forbids.
 *
 * The values were written as UTC by Laravel, so `AT TIME ZONE 'UTC'` reads
 * them back as the instants they always meant.
 */
return new class extends Migration
{
    /** @var list<string> */
    private const COLUMNS = ['last_used_at', 'expires_at', 'created_at', 'updated_at'];

    public function up(): void
    {
        foreach (self::COLUMNS as $column) {
            DB::statement(
                "alter table personal_access_tokens alter column {$column} type timestamptz using {$column} at time zone 'UTC'"
            );
        }
    }

    public function down(): void
    {
        foreach (self::COLUMNS as $column) {
            DB::statement(
                "alter table personal_access_tokens alter column {$column} type timestamp using {$column} at time zone 'UTC'"
            );
        }
    }
};
