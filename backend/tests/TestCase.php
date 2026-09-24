<?php

declare(strict_types=1);

namespace Tests;

use Illuminate\Contracts\Auth\Authenticatable;
use Illuminate\Foundation\Testing\TestCase as BaseTestCase;
use Illuminate\Testing\TestResponse;
use RuntimeException;

abstract class TestCase extends BaseTestCase
{
    /** @var array{Authenticatable, string|null}|null */
    private ?array $impersonation = null;

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

    /**
     * Remember an `actingAs()` user so that the reset in `call()` can put it
     * back; otherwise the reset would turn every impersonated request into a
     * guest request.
     *
     * @param  string|null  $guard
     */
    public function be(Authenticatable $user, $guard = null): static
    {
        $this->impersonation = [$user, $guard];

        return parent::be($user, $guard);
    }

    /**
     * Every request in a test starts with no cached authenticated user.
     *
     * The application instance lives for the whole test, and the auth guards
     * cache the user they resolved for the first request. A second request in
     * the same test carrying another token — or no token — would otherwise be
     * served as the first request's user, which is not how HTTP works and
     * which would let a test pass that proves the opposite of its name. A user
     * set through `actingAs()` is re-applied after the reset. `Sanctum::actingAs()`
     * is not supported; tests authenticate with real tokens or `actingAs()`.
     *
     * @param  string  $method
     * @param  string  $uri
     * @param  array<string, mixed>  $parameters
     * @param  array<string, mixed>  $cookies
     * @param  array<string, mixed>  $files
     * @param  array<string, mixed>  $server
     * @param  string|null  $content
     */
    public function call($method, $uri, $parameters = [], $cookies = [], $files = [], $server = [], $content = null): TestResponse
    {
        $this->app['auth']->forgetGuards();

        if ($this->impersonation !== null) {
            parent::be($this->impersonation[0], $this->impersonation[1]);
        }

        return parent::call($method, $uri, $parameters, $cookies, $files, $server, $content);
    }
}
