<?php

declare(strict_types=1);

namespace Tests\Support\Database;

/**
 * Rolls back a wave's migrations and runs them again, the way a real rollback
 * would: newest first, and every later migration with them, since a later
 * table may refer to one of the wave's (an order refers to an address, a line
 * to a product). A wave's rollback test then keeps working when later waves
 * add tables, without naming them.
 *
 * The rollback runs inside the test's transaction; PostgreSQL DDL is
 * transactional, so the database is back as it was when the test ends.
 */
trait RollsBackMigrations
{
    /**
     * Rolls back every migration from $firstFile on, newest first.
     *
     * @return list<string> the files rolled back, oldest first, for runAgain()
     */
    private function rollBackFrom(string $firstFile): array
    {
        $files = array_values(array_filter(
            $this->migrationFiles(),
            static fn (string $file): bool => strcmp($file, $firstFile) >= 0
        ));

        foreach (array_reverse($files) as $file) {
            $this->runMigration($file, 'down');
        }

        return $files;
    }

    /**
     * @param  list<string>  $files  oldest first
     */
    private function runAgain(array $files): void
    {
        foreach ($files as $file) {
            $this->runMigration($file, 'up');
        }
    }

    /**
     * @return list<string> every migration file name without its extension, oldest first
     */
    private function migrationFiles(): array
    {
        $files = array_map(
            static fn (string $path): string => basename($path, '.php'),
            glob(database_path('migrations/*.php')) ?: []
        );
        sort($files);

        return $files;
    }

    /**
     * Runs one direction of one migration file. The file returns an anonymous
     * class, so the method is called by name.
     */
    private function runMigration(string $file, string $direction): void
    {
        $migration = require database_path("migrations/{$file}.php");

        $migration->{$direction}();
    }
}
