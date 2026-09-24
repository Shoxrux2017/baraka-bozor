<?php

declare(strict_types=1);

namespace Tests;

use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use RuntimeException;

abstract class TestCase extends BaseTestCase
{
    /**
     * Refuse to run against any database that is not a test database.
     *
     * `RefreshDatabase` runs `migrate:fresh`, which drops every table. Should
     * the connection ever resolve to the development database — an outer
     * environment variable that got past phpunit.xml, a changed .env — this
     * check stops the run before the first table is dropped: the application
     * is created here, and the traits that migrate run right after. That is
     * what `TestDatabaseIsolationTest` cannot promise; it proves the live
     * connection, but only once it is reached.
     */
    protected function refreshApplication(): void
    {
        parent::refreshApplication();

        $connection = (string) config('database.default');
        $database = (string) config("database.connections.{$connection}.database");

        if (! str_ends_with($database, '_test')) {
            throw new RuntimeException(
                "Refusing to run the suite against database \"{$database}\" on connection \"{$connection}\": "
                .'tests may only run against a database named *_test.'
            );
        }
    }
}
