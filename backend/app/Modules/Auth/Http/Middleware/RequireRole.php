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
 * the Operator surface is the Admin surface with parts hidden: every route
 * under `/operations` names both roles and no route elsewhere names the
 * Operator (`DL-12`, enforced by `ProtectedRoutesTest`). A role outside the
 * list is refused with `403 forbidden`; the record scope (layer 4) is the
 * action's job and answers a scope-safe 404, never this.
 *
 * Declared after the `protected` group, which has already proven the token,
 * the active status and the password gate; the structural test refuses a
 * route that carries this middleware without them.
 */
final class RequireRole
{
    public const ALIAS = 'role';

    public function handle(Request $request, Closure $next, string ...$roles): Response
    {
        if ($roles === [] || $roles === ['']) {
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
     * At least one role, by signature, so `role:` with nothing after it cannot
     * be produced here.
     */
    public static function of(Role $first, Role ...$rest): string
    {
        $roles = [$first, ...$rest];

        return self::ALIAS.':'.implode(',', array_map(static fn (Role $role): string => $role->value, $roles));
    }
}
