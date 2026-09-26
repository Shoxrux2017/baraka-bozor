<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;

/**
 * Asserts that PostgreSQL refuses an update, and refuses it for the stated
 * reason — the update-shaped twin of `AssertsDatabaseRejections`, for the
 * singleton tables whose only row already exists.
 */
trait AssertsUpdateRejections
{
    /**
     * @param  array<string, mixed>  $where
     * @param  array<string, mixed>  $values
     */
    private function assertUpdateRejectedBy(
        string $table,
        string $constraint,
        array $where,
        array $values,
        string $why
    ): void {
        // A savepoint per attempt, for the same reason as in
        // AssertsDatabaseRejections: a failed statement poisons the transaction
        // RefreshDatabase wraps around the test.
        DB::beginTransaction();

        $message = '';

        try {
            DB::table($table)->where($where)->update($values);
            $accepted = true;
        } catch (QueryException $exception) {
            $accepted = false;
            $message = $exception->getMessage();
        } finally {
            DB::rollBack();
        }

        if ($accepted) {
            $this->fail(sprintf('PostgreSQL accepted the update. %s Expected "%s" to reject it.', $why, $constraint));
        }

        $this->assertStringContainsString(
            $constraint,
            $message,
            sprintf('The update was rejected, but not by "%s". %s', $constraint, $why)
        );
    }
}
