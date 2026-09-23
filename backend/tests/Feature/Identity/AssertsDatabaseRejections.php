<?php

declare(strict_types=1);

namespace Tests\Feature\Identity;

use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;

/**
 * Asserts that PostgreSQL refuses a row, and refuses it for the stated reason.
 *
 * Shared by the two identity tables because both enforce their invariants in the
 * database rather than in a request rule, and both therefore have to prove it the
 * same way.
 */
trait AssertsDatabaseRejections
{
    /**
     * @param  array<string, mixed>  $row
     * @param  string  $why  stated in the failure message, so a red run explains
     *                       the rule rather than only the SQL
     */
    private function assertRejectedBy(string $table, string $constraint, array $row, string $why): void
    {
        // Each attempt gets its own savepoint. In PostgreSQL a failed statement
        // poisons the whole transaction — including the one `RefreshDatabase`
        // opens around every test — so without this, the second rejection a test
        // checks would come back as 25P02 "current transaction is aborted"
        // rather than as the constraint under test, and the test would report a
        // missing constraint that is in fact present. Nesting here makes Laravel
        // issue SAVEPOINT / ROLLBACK TO SAVEPOINT, which leaves rows inserted
        // earlier in the same test untouched.
        DB::beginTransaction();

        $message = '';

        try {
            DB::table($table)->insert($row);
            $accepted = true;
        } catch (QueryException $exception) {
            $accepted = false;
            $message = $exception->getMessage();
        } finally {
            DB::rollBack();
        }

        if ($accepted) {
            $this->fail(sprintf(
                'PostgreSQL accepted the row. %s Expected "%s" to reject it.',
                $why,
                $constraint
            ));
        }

        $this->assertStringContainsString(
            $constraint,
            $message,
            sprintf(
                'The row was rejected, but not by "%s". %s A different constraint firing here '
                .'would leave this invariant unguarded while the test still passed.',
                $constraint,
                $why
            )
        );
    }
}
