<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Middleware;

use App\Exceptions\ApiException;
use App\Models\Enums\Role;
use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use InvalidArgumentException;
use Symfony\Component\HttpFoundation\Response;

/**
 * Layer 3 of `docs/07-architecture.md` Section 9: role capability.
 *
 * `role:admin` admits Admins; `role:operator,admin` admits both, which is how
 * the Operator surface is the Admin surface with parts hidden — every
 * operations endpoint names both roles, every admin-only endpoint names one.
 * A role outside the list is refused with `403 forbidden`; the record scope
 * (layer 4) is the action's job and answers a scope-safe 404, never this.
 *
 * Runs after the `protected` group, which has already proven the token, the
 * active status and the password gate.
 */
final class RequireRole
{
    public const ALIAS = 'role';

    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        if ($roles === []) {
            throw new InvalidArgumentException('role middleware needs at least one role, for example role:admin.');
        }

        $admitted = array_map(static fn (string $role): Role => Role::from($role), $roles);

        $user = $request->user();

        if (! $user instanceof User) {
            // Unreachable behind auth:sanctum; refused rather than assumed.
            throw ApiException::unauthenticated('authentication_required');
        }

        if (! in_array($user->role, $admitted, true)) {
            throw ApiException::forbidden('forbidden');
        }

        return $next($request);
    }

    /**
     * The middleware string for a route: `RequireRole::of(Role::Operator, Role::Admin)`.
     */
    public static function of(Role ...$roles): string
    {
        return self::ALIAS.':'.implode(',', array_map(static fn (Role $role): string => $role->value, $roles));
    }
}
