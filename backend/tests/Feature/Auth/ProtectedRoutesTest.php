<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\Enums\Role;
use App\Modules\Auth\Http\Middleware\EnsureAccountActive;
use App\Modules\Auth\Http\Middleware\EnsurePasswordChanged;
use App\Modules\Auth\Http\Middleware\RequireRole;
use App\Support\Routing\UuidRouteParameters;
use Illuminate\Routing\Route as RouteInstance;
use Illuminate\Routing\Router;
use Illuminate\Support\Facades\Route;
use Tests\TestCase;

/**
 * Structural guards over the production route table.
 *
 * Each of these is a rule a single forgotten line would break silently: a
 * route authenticating without re-checking the account status (docs/07
 * Section 8), a role check mounted without the token, status and gate checks
 * before it (docs/07 Section 9), an Operator admitted outside the operations
 * surface (DL-12), a misspelled role that would fail only when hit, or a UUID
 * parameter left unconstrained so a malformed id reaches a query.
 */
final class ProtectedRoutesTest extends TestCase
{
    private const AUTHENTICATE = 'Illuminate\Auth\Middleware\Authenticate:sanctum';

    public function test_every_authenticated_api_route_re_checks_the_account_status(): void
    {
        $checked = 0;

        foreach ($this->apiRoutes() as [$route, $middleware]) {
            if (! in_array(self::AUTHENTICATE, $middleware, true)) {
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

    public function test_a_role_check_always_comes_after_the_token_status_and_gate_checks(): void
    {
        foreach ($this->routesOrFail() as [$route, $middleware]) {
            $roleAt = array_search(RequireRole::class, $middleware, true);

            if ($roleAt === false) {
                continue;
            }

            foreach ([self::AUTHENTICATE, EnsureAccountActive::class, EnsurePasswordChanged::class] as $required) {
                $requiredAt = array_search($required, $middleware, true);

                $this->assertNotFalse($requiredAt, "Route {$route->uri()} checks the role without {$required}.");
                $this->assertLessThan($roleAt, $requiredAt, "Route {$route->uri()} checks the role before {$required}.");
            }
        }
    }

    public function test_every_declared_role_is_a_real_role(): void
    {
        foreach ($this->routesOrFail() as [$route]) {
            foreach ($this->declaredRoles($route) as $role) {
                $this->assertNotNull(
                    Role::tryFrom($role),
                    "Route {$route->uri()} names the role \"{$role}\", which does not exist."
                );
            }
        }
    }

    public function test_the_operator_is_admitted_only_on_the_operations_surface(): void
    {
        // DL-12: the Operator surface is the Admin surface with parts hidden,
        // expressed as every /operations route naming both roles and no other
        // route naming the Operator.
        foreach ($this->routesOrFail() as [$route]) {
            $roles = $this->declaredRoles($route);

            if ($roles === []) {
                continue;
            }

            $isOperations = str_starts_with($route->uri(), 'api/v1/operations');

            $this->assertSame(
                $isOperations,
                in_array(Role::Operator->value, $roles, true),
                "Route {$route->uri()} ".($isOperations ? 'must admit the Operator' : 'must not admit the Operator').'.'
            );

            if ($isOperations) {
                $this->assertContains(Role::Admin->value, $roles, "Route {$route->uri()} must admit the Admin as well.");
            }
        }
    }

    public function test_every_route_parameter_is_a_constrained_uuid_or_a_closed_enum(): void
    {
        foreach ($this->routesOrFail() as [$route]) {
            foreach ($route->parameterNames() as $parameter) {
                $enum = UuidRouteParameters::ENUMS[$parameter] ?? null;

                if ($enum !== null) {
                    $this->assertSame(
                        UuidRouteParameters::enumPattern($enum),
                        $route->wheres[$parameter] ?? null,
                        "Route {$route->uri()} parameter \"{$parameter}\" is not constrained to the values of {$enum}."
                    );

                    continue;
                }

                $this->assertContains(
                    $parameter,
                    UuidRouteParameters::NAMES,
                    "Route {$route->uri()} has a parameter \"{$parameter}\" that UuidRouteParameters does not constrain."
                );
                $this->assertSame(
                    UuidRouteParameters::PATTERN,
                    $route->wheres[$parameter] ?? null,
                    "Route {$route->uri()} parameter \"{$parameter}\" is not constrained to a UUID."
                );
            }
        }
    }

    /**
     * The production routes, asserted non-empty so a rule with nothing to
     * inspect yet still counts as a checked rule rather than a risky test.
     *
     * @return list<array{RouteInstance, list<string>}>
     */
    private function routesOrFail(): array
    {
        $routes = $this->apiRoutes();

        $this->assertNotEmpty($routes, 'The production route table is empty; the module loader lost its routes.');

        return $routes;
    }

    /**
     * @return list<array{RouteInstance, list<string>}>
     */
    private function apiRoutes(): array
    {
        $router = $this->app->make(Router::class);
        $routes = [];

        foreach (Route::getRoutes()->getRoutes() as $route) {
            if (! str_starts_with($route->uri(), 'api/v1')) {
                continue;
            }

            $middleware = array_values(array_map(
                static fn ($entry): string => is_string($entry) ? $entry : get_class($entry),
                $router->gatherRouteMiddleware($route)
            ));

            $routes[] = [$route, $middleware];
        }

        return $routes;
    }

    /**
     * The roles a route's `role:` middleware names, before resolution.
     *
     * @return list<string>
     */
    private function declaredRoles(RouteInstance $route): array
    {
        foreach ($route->middleware() as $entry) {
            if (str_starts_with($entry, RequireRole::ALIAS.':')) {
                return explode(',', substr($entry, strlen(RequireRole::ALIAS) + 1));
            }
        }

        return [];
    }
}
