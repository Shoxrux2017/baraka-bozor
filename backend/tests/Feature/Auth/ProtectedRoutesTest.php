<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Modules\Auth\Http\Middleware\EnsureAccountActive;
use Illuminate\Routing\Route as RouteInstance;
use Illuminate\Routing\Router;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

/**
 * Structural guard for `docs/07-architecture.md` Section 8: every
 * authenticated production route re-checks the account's status. A route
 * declared with bare `auth:sanctum` and no `account.active` would let a
 * blocked account keep using a token the block forgot to delete.
 */
final class ProtectedRoutesTest extends TestCase
{
    public function test_every_authenticated_api_route_re_checks_the_account_status(): void
    {
        $router = $this->app->make(Router::class);
        $checked = 0;

        foreach (Route::getRoutes()->getRoutes() as $route) {
            if (! str_starts_with($route->uri(), 'api/v1')) {
                continue;
            }

            $middleware = $this->resolvedMiddleware($router, $route);

            if (! in_array('Illuminate\Auth\Middleware\Authenticate:sanctum', $middleware, true)) {
                continue;
            }

            $checked++;

            $this->assertContains(
                EnsureAccountActive::class,
                $middleware,
                "Route {$route->uri()} authenticates without re-checking the account status."
            );
        }

        $this->assertGreaterThan(0, $checked, 'The auth module declares authenticated routes.');
    }

    /**
     * @return list<string>
     */
    private function resolvedMiddleware(Router $router, RouteInstance $route): array
    {
        return array_values(array_map(
            static fn ($middleware): string => is_string($middleware) ? $middleware : get_class($middleware),
            $router->gatherRouteMiddleware($route)
        ));
    }
}
