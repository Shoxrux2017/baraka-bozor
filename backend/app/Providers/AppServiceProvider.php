<?php

declare(strict_types=1);

namespace App\Providers;

use App\Support\Routing\UuidRouteParameters;
use App\Support\Runtime\ProductionConfiguration;
use Illuminate\Routing\Router;
use Illuminate\Support\ServiceProvider;
use Laravel\Boost\BoostServiceProvider;
use Laravel\Mcp\Server\McpServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        // Laravel Boost, the agent's development tool, loads only for console
        // commands in the local environment (`DL-106`). Discovered, laravel/mcp
        // would add a global middleware to every request, the test suite's too;
        // the production image has neither package.
        if ($this->app->environment('local') && $this->app->runningInConsole() && class_exists(BoostServiceProvider::class)) {
            $this->app->register(McpServiceProvider::class);
            $this->app->register(BoostServiceProvider::class);
        }
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(Router $router): void
    {
        // Before any route is registered: patterns apply at registration time.
        UuidRouteParameters::register($router);

        // An incomplete production configuration stops the boot, not the first
        // request that needs the missing setting (`DL-107`). Package discovery
        // is exempt: Composer runs it before any env file exists, and it only
        // writes the package manifest.
        if ($this->app->environment('production') && ! $this->app->runningConsoleCommand('package:discover')) {
            ProductionConfiguration::assertComplete($this->app);
        }
    }
}
