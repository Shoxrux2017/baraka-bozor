<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Guards the one property no other test can notice being broken.
 *
 * The suite must run on PostgreSQL, and on a database that is not the one used
 * for development. Both were silently false once: `backend/phpunit.xml` pinned
 * the test connection with plain `<env>` entries, which PHPUnit applies only
 * when the variable is absent from the real environment, so `DB_*` set by
 * Compose won and the suite ran against the development database while
 * reporting green.
 *
 * Nothing broke at the time because no test touched the database. The first one
 * that does will use `RefreshDatabase`, which drops every table it finds.
 */
class TestDatabaseIsolationTest extends TestCase
{
    public function test_the_suite_runs_on_postgresql(): void
    {
        $this->assertSame(
            'pgsql',
            DB::connection()->getDriverName(),
            'The suite fell back off PostgreSQL. SQLite diverges on column types, '
            .'partial unique indexes and transaction behavior, so a green run on it '
            .'proves nothing about production. See docs/07-architecture.md Section 33.'
        );
    }

    public function test_the_suite_runs_on_a_dedicated_test_database(): void
    {
        $database = DB::connection()->getDatabaseName();

        $this->assertNotSame('', $database, 'No database name resolved for the test connection.');

        $this->assertStringEndsWith(
            '_test',
            $database,
            sprintf(
                'The suite is connected to "%s", which is not a dedicated test database. '
                .'A destructive test would wipe development data. Check that every DB_* entry '
                .'in backend/phpunit.xml carries force="true", and that nothing in the '
                .'environment — Compose, a shell, a CI runner — sets DB_DATABASE.',
                $database
            )
        );
    }
}
