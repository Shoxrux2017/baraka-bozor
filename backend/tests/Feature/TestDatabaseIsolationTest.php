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
 *
 * Both checks ask the server, not the configuration. Laravel resolves its PDO
 * lazily, so `getDriverName()` and `getDatabaseName()` answer from config and
 * would pass with the database stopped.
 *
 * Limitation worth knowing: the second check tests the *shape* of the database
 * name, not that it differs from the one a particular developer works in. A
 * `backend/.env` that also points at a `_test` database would satisfy it and
 * still be wiped. The suffix convention is what makes the check survive a
 * rename and a differently-named CI database.
 */
class TestDatabaseIsolationTest extends TestCase
{
    public function test_the_suite_runs_on_postgresql(): void
    {
        $row = DB::selectOne('select version() as server');

        $this->assertNotNull($row, 'The test database did not answer. Is the Compose stack running?');

        $this->assertStringContainsString(
            'PostgreSQL',
            (string) $row->server,
            'The suite is not talking to PostgreSQL. SQLite diverges on column types, '
            .'partial unique indexes and transaction behavior, so a green run on it '
            .'proves nothing about production. See docs/07-architecture.md Section 33.'
        );

        $this->assertSame('pgsql', DB::connection()->getDriverName());
    }

    public function test_the_suite_runs_on_a_dedicated_test_database(): void
    {
        $row = DB::selectOne('select current_database() as name');

        $this->assertNotNull($row, 'The test database did not answer. Is the Compose stack running?');

        $database = (string) $row->name;

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
