<?php

declare(strict_types=1);

namespace Tests\Feature\Identity;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\Database\ReadsPostgresCatalog;
use Tests\TestCase;

/**
 * The `users` table is a locked schema contract, not an implementation detail:
 * `08` Section 3 names every column, and `08` Section 1 fixes the types those
 * columns must have.
 *
 * Every assertion here asks PostgreSQL what it actually built, through
 * `information_schema`, rather than reading the migration source back. A
 * migration says what was requested; the catalog says what exists. The two
 * diverge in exactly the case this task most needs to catch — Laravel's
 * `timestamps()` and `timestamp()` emit `timestamp without time zone` on
 * PostgreSQL, so a migration that looks correct produces columns that are not
 * the `timestamptz` `08` Section 1 requires.
 */
final class UsersTableShapeTest extends TestCase
{
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    /**
     * Every column `08` Section 3 names, with the type and nullability it fixes.
     *
     * @return array<string, array{string, bool}> column => [type, nullable]
     */
    private function expectedColumns(): array
    {
        return [
            'id' => ['uuid', false],
            'role' => ['character varying', false],
            'phone' => ['character varying', false],
            'full_name' => ['character varying', true],
            'password' => ['character varying', true],
            'status' => ['character varying', false],
            'must_change_password' => ['boolean', false],
            'password_changed_at' => ['timestamp with time zone', true],
            'last_login_at' => ['timestamp with time zone', true],
            'blocked_at' => ['timestamp with time zone', true],
            'created_by_user_id' => ['uuid', true],
            'preferred_language' => ['character varying', false],
            'created_at' => ['timestamp with time zone', false],
            'updated_at' => ['timestamp with time zone', false],
        ];
    }

    public function test_it_has_exactly_the_columns_the_locked_schema_names(): void
    {
        $actual = array_keys($this->columnsOf('users'));
        $expected = array_keys($this->expectedColumns());

        sort($actual);
        sort($expected);

        $this->assertSame(
            $expected,
            $actual,
            'The users table does not carry exactly the columns docs/08-database.md Section 3 names. '
            .'An extra column is scope creep; a missing one breaks a locked contract.'
        );
    }

    public function test_every_column_has_the_type_and_nullability_the_locked_schema_fixes(): void
    {
        $actual = $this->columnsOf('users');

        foreach ($this->expectedColumns() as $column => [$type, $nullable]) {
            $this->assertArrayHasKey($column, $actual, "users.{$column} is missing.");

            $this->assertSame(
                $type,
                $actual[$column]->data_type,
                sprintf('users.%s is %s, expected %s.', $column, $actual[$column]->data_type, $type)
            );

            $this->assertSame(
                $nullable ? 'YES' : 'NO',
                $actual[$column]->is_nullable,
                sprintf(
                    'users.%s nullability does not match docs/08-database.md Section 3.',
                    $column
                )
            );
        }
    }

    public function test_every_instant_is_stored_with_a_time_zone(): void
    {
        // Stated separately from the type check above because this is the trap
        // the whole table walks into at once: `timestamps()` and `timestamp()`
        // both emit `timestamp without time zone` on PostgreSQL, so all five
        // instants would be wrong together and for one reason. A named test
        // says which rule was broken instead of reporting five type mismatches.
        foreach (['password_changed_at', 'last_login_at', 'blocked_at', 'created_at', 'updated_at'] as $column) {
            $this->assertSame(
                'timestamp with time zone',
                $this->columnsOf('users')[$column]->data_type,
                sprintf(
                    'users.%s is not timestamptz. docs/08-database.md Section 1 requires a time zone on '
                    .'authoritative instants, and Laravel\'s timestamps()/timestamp() do not provide one '
                    .'on PostgreSQL — timestampTz()/timestampsTz() do.',
                    $column
                )
            );
        }
    }

    public function test_the_locked_column_lengths_hold(): void
    {
        $lengths = ['role' => 24, 'phone' => 20, 'full_name' => 160, 'password' => 255, 'status' => 16];

        $actual = $this->columnsOf('users');

        foreach ($lengths as $column => $length) {
            $this->assertSame(
                $length,
                $actual[$column]->character_maximum_length,
                sprintf('users.%s is not varchar(%d) as docs/08-database.md Section 3 fixes.', $column, $length)
            );
        }
    }
}
