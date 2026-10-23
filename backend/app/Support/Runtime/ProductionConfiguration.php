<?php

declare(strict_types=1);

namespace App\Support\Runtime;

use App\Modules\Accounts\PhoneFingerprint;
use App\Modules\Auth\CodeDelivery\CodeDeliveryGateway;
use Illuminate\Contracts\Foundation\Application;
use RuntimeException;

/**
 * The production boot check (`DL-107`): a production box with a missing secret
 * or an unsafe setting must not start serving in silence. It names the settings
 * that are wrong and never their values (`AGENTS.md` §5). Exactly one CORS
 * origin is required: Caddy copies the variable verbatim into a header that
 * takes one.
 */
final class ProductionConfiguration
{
    /**
     * @return list<string> the names of the settings that are missing or unsafe
     */
    public static function problems(): array
    {
        $problems = [];

        if (self::blank(config('app.key'))) {
            $problems[] = 'APP_KEY';
        }

        if (config('app.debug') === true) {
            $problems[] = 'APP_DEBUG';
        }

        $url = config('app.url');

        if (! is_string($url) || ! str_starts_with($url, 'https://')) {
            $problems[] = 'APP_URL';
        }

        $connection = config('database.default');

        if (! is_string($connection) || self::blank(config("database.connections.{$connection}.password"))) {
            $problems[] = 'DB_PASSWORD';
        }

        if (! is_string(config('login_codes.driver')) || self::blank(config('login_codes.driver'))) {
            $problems[] = 'LOGIN_CODE_DRIVER';
        }

        $origins = config('cors.allowed_origins');

        if (! is_array($origins) || count($origins) !== 1 || in_array('*', $origins, true)) {
            $problems[] = 'CORS_ALLOWED_ORIGINS';
        }

        $proxies = config('trustedproxy.proxies');

        if ($proxies === null || $proxies === [] || $proxies === '') {
            $problems[] = 'TRUSTED_PROXIES';
        }

        if (self::blank(config('accounts.phone_fingerprint.key'))) {
            $problems[] = 'PHONE_FINGERPRINT_KEY';
        }

        return $problems;
    }

    /**
     * Beyond presence, resolves the code gateway and computes one fingerprint,
     * so an unknown driver or a malformed key fails here with its own message
     * rather than at the first sign-in or erasure.
     */
    public static function assertComplete(Application $app): void
    {
        $problems = self::problems();

        if ($problems !== []) {
            throw new RuntimeException('Production configuration is incomplete or unsafe: '.implode(', ', $problems).'.');
        }

        $app->make(CodeDeliveryGateway::class);
        PhoneFingerprint::of('+998900000000');
    }

    private static function blank(mixed $value): bool
    {
        return ! is_string($value) || trim($value) === '';
    }
}
