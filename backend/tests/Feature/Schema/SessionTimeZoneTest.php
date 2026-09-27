<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Laravel binds and saves an instant as `Y-m-d H:i:s`, without its offset, so
 * PostgreSQL reads it in the session's time zone. The connection sets that
 * zone to UTC, whatever the server or the database defaults to (`DL-44` (8)):
 * a server installed in `Asia/Tashkent` would otherwise shift every order's
 * instants and every day of the board by five hours.
 *
 * Not `RefreshDatabase`: the test reconnects, which a wrapping transaction
 * would not survive.
 */
final class SessionTimeZoneTest extends TestCase
{
    public function test_a_session_reads_instants_in_utc_whatever_the_database_defaults_to(): void
    {
        $database = DB::connection()->getDatabaseName();
        $this->assertStringEndsWith('_test', $database, 'The test changes a database default; it runs on the test database only.');
        $name = DB::connection()->getQueryGrammar()->wrap($database);

        DB::statement("alter database {$name} set timezone to 'Asia/Tashkent'");
        try {
            DB::reconnect();

            $this->assertSame('UTC', DB::selectOne("select current_setting('TimeZone') as zone")?->zone);
            $this->assertSame(
                '2026-09-26 19:30:00+00',
                DB::selectOne("select '2026-09-26 19:30:00'::timestamptz::text as instant")?->instant,
            );
        } finally {
            DB::statement("alter database {$name} reset timezone");
            DB::reconnect();
        }
    }
}
