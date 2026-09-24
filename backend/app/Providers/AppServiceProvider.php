<?php

declare(strict_types=1);

namespace App\Providers;

use App\Support\Routing\UuidRouteParameters;
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
    }
}
