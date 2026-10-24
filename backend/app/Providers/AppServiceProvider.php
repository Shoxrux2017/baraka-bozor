<?php

declare(strict_types=1);

namespace App\Providers;

use App\Support\Routing\UuidRouteParameters;
use App\Support\Runtime\ProductionConfiguration;
use Illuminate\Routing\Router;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
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
