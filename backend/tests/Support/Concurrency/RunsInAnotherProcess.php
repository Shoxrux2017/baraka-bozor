<?php

declare(strict_types=1);

namespace Tests\Support\Concurrency;

use Illuminate\Process\InvokedProcess;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Process;

/**
 * Runs one step of a concurrency test in another PHP process (`run.php`), so
 * a test can let that step block on a lock the test holds, change what the
 * step is waiting for, commit, and see what the step made of it — the
 * interleaving two requests produce in production, which one process cannot
 * stage.
 *
 * The test does not sleep for a guessed time: it waits until PostgreSQL
 * reports another backend waiting on a lock, with a deadline.
 */
trait RunsInAnotherProcess
{
    private function startElsewhere(string $scenario, string ...$arguments): InvokedProcess
    {
        /** @var array{host: string, port: int|string, database: string, username: string, password: string} $database */
        $database = config('database.connections.pgsql');

        return Process::path(base_path())
            ->env([
                'APP_ENV' => 'testing',
                'DB_CONNECTION' => 'pgsql',
                'DB_URL' => '',
                'DB_HOST' => $database['host'],
                'DB_PORT' => (string) $database['port'],
                'DB_DATABASE' => $database['database'],
                'DB_USERNAME' => $database['username'],
                'DB_PASSWORD' => $database['password'],
            ])
            ->timeout(60)
            ->start([PHP_BINARY, 'tests/Support/Concurrency/run.php', $scenario, ...$arguments]);
    }

    private function waitUntilAnotherBackendWaitsOnALock(float $deadlineSeconds = 20.0): void
    {
        $deadline = microtime(true) + $deadlineSeconds;

        do {
            $waiting = (int) DB::selectOne(
                "select count(*) as waiting from pg_stat_activity
                  where datname = current_database() and pid <> pg_backend_pid() and wait_event_type = 'Lock'"
            )->waiting;

            if ($waiting > 0) {
                return;
            }

            usleep(20_000);
        } while (microtime(true) < $deadline);

        $this->fail('No other process came to wait on a lock.');
    }

    /**
     * @return array<string, mixed>
     */
    private function outcomeOf(InvokedProcess $process): array
    {
        $result = $process->wait();
        $this->assertSame(0, $result->exitCode(), $result->errorOutput());

        /** @var array<string, mixed> $outcome */
        $outcome = json_decode($result->output(), true, flags: JSON_THROW_ON_ERROR);

        return $outcome;
    }
}
