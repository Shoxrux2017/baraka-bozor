<?php

declare(strict_types=1);

namespace App\Modules\Auth;

use App\Modules\Auth\Http\Middleware\EnsureAccountActive;
use App\Modules\Auth\Http\Middleware\EnsurePasswordChanged;
use App\Modules\Auth\Sanctum\TokenLifetime;
use Illuminate\Routing\Router;
use Illuminate\Support\ServiceProvider;
use Laravel\Sanctum\PersonalAccessToken;
use Laravel\Sanctum\Sanctum;

/**
 * Wires the authentication module: the middleware every protected route
 * uses, and the token validity rule Sanctum consults on each request.
 *
 * Collected by the module provider registry; nothing lists this class by hand.
 */
final class AuthServiceProvider extends ServiceProvider
{
    /**
     * The middleware group a protected endpoint declares. Order matters: the
     * token identifies the account, the account must be active, and the
     * first-login gate must be cleared, in that sequence.
     */
    public const PROTECTED = 'protected';

    public function boot(Router $router): void
    {
        $router->aliasMiddleware('account.active', EnsureAccountActive::class);
        $router->aliasMiddleware('password.changed', EnsurePasswordChanged::class);
        $router->middlewareGroup(self::PROTECTED, ['auth:sanctum', 'account.active', 'password.changed']);

        // `docs/07-architecture.md` Section 8: a token is valid for 30 days
        // from its last use, not from issue. A stale token is deleted on
        // sight, so the table does not accumulate dead rows.
        Sanctum::authenticateAccessTokensUsing(
            static function (PersonalAccessToken $token, bool $isValid): bool {
                if (! $isValid) {
                    return false;
                }

                if (TokenLifetime::isAlive($token)) {
                    return true;
                }

                $token->delete();

                return false;
            }
        );
    }
}
