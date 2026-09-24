<?php

declare(strict_types=1);

namespace App\Modules\Auth;

use App\Modules\Auth\CodeDelivery\CodeDeliveryGateway;
use App\Modules\Auth\CodeDelivery\FakeCodeDelivery;
use App\Modules\Auth\CodeDelivery\FakeCodeSink;
use App\Modules\Auth\Http\Middleware\EnsureAccountActive;
use App\Modules\Auth\Http\Middleware\EnsurePasswordChanged;
use App\Modules\Auth\Http\Middleware\RequireRole;
use App\Modules\Auth\Sanctum\TokenLifetime;
use Illuminate\Contracts\Foundation\Application;
use Illuminate\Routing\Router;
use Illuminate\Support\ServiceProvider;
use Laravel\Sanctum\PersonalAccessToken;
use Laravel\Sanctum\Sanctum;
use RuntimeException;

/**
 * Wires the authentication module: the code-delivery gateway, the test
 * phones, the middleware every protected route uses, and the token validity
 * rule Sanctum consults on each request.
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

    public function register(): void
    {
        $this->app->singleton(FakeCodeSink::class);
        $this->app->singleton(
            TestPhones::class,
            static fn (Application $app): TestPhones => TestPhones::fromConfig($app->environment('production'))
        );

        $this->app->bind(CodeDeliveryGateway::class, static function (Application $app): CodeDeliveryGateway {
            $driver = config('login_codes.driver');

            return match ($driver) {
                'fake' => $app->make(FakeCodeDelivery::class),
                // `telegram` arrives with Wave 4 and `sms` with Wave 5.
                default => throw new RuntimeException(
                    'LOGIN_CODE_DRIVER is '.json_encode($driver).'; only "fake" exists yet, and production must set it explicitly.'
                ),
            };
        });
    }

    public function boot(Router $router): void
    {
        // Resolved now rather than at the first login, so a bad test-phone
        // configuration, or one present in production, fails the boot.
        $this->app->make(TestPhones::class);

        $router->aliasMiddleware('account.active', EnsureAccountActive::class);
        $router->aliasMiddleware('password.changed', EnsurePasswordChanged::class);
        $router->aliasMiddleware(RequireRole::ALIAS, RequireRole::class);
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
