<?php

declare(strict_types=1);

namespace App\Providers;

use App\Support\Routing\UuidRouteParameters;
use App\Support\Runtime\ProductionConfiguration;
use Illuminate\Routing\Router;
use Illuminate\Support\Facades\DB;
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

        // Every environment but the two development ones is a server, a typo
        // such as `prod` included: an incomplete configuration stops the boot,
        // not the first request that needs the missing setting (`DL-107`,
        // `DL-141`). Package discovery is exempt: Composer runs it before any
        // env file exists, and it only writes the package manifest.
        $server = ! $this->app->environment(['local', 'testing']);

        if ($server && ! $this->app->runningConsoleCommand('package:discover')) {
            ProductionConfiguration::assertComplete($this->app);
        }

        // A server never wipes or rebuilds its database from an artisan command.
        DB::prohibitDestructiveCommands($server);
    }
}
