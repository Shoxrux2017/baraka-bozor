<?php

declare(strict_types=1);

namespace App\Modules\Auth\Http\Middleware;

use App\Exceptions\ApiException;
use App\Models\Enums\UserStatus;
use App\Models\User;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

/**
 * Refuses a valid token whose account has since been blocked.
 *
 * Blocking deletes every token of the account, and this check runs on every
 * request as well — two independent barriers, deliberately redundant, because
 * the person being blocked may hold order, assignment and money capabilities
 * (`docs/07-architecture.md` Section 8). `401`, not `403`: the client acts on
 * a 401 by discarding the token and returning to sign-in, which is the right
 * outcome for a blocked account.
 *
 * Runs after `auth:sanctum`, which is what resolves the user.
 */
final class EnsureAccountActive
{
    public function handle(Request $request, Closure $next): Response
    {
        $user = $request->user();

        if ($user instanceof User && $user->status === UserStatus::Blocked) {
            // A token that reached here should already be gone; make sure.
            $user->tokens()->delete();

            throw ApiException::unauthenticated('account_blocked');
        }

        return $next($request);
    }
}
