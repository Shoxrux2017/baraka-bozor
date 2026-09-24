<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Middleware;

use App\Exceptions\ApiException;
use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * The first-login gate of `BR-ROLE-006`.
 *
 * A staff account created with a temporary password may only read its
 * identity, change its password and log out until the password is changed.
 * Every other protected endpoint carries this middleware through the
 * `protected` group; the three onboarding endpoints deliberately do not.
 */
final class EnsurePasswordChanged
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user instanceof User && $user->must_change_password) {
            throw ApiException::forbidden('password_change_required');
        }

        return $next($request);
    }
}
