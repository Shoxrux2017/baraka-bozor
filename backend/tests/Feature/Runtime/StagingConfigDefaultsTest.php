<?php

declare(strict_types=1);

namespace Tests\Feature\Runtime;

use Tests\TestCase;

/**
 * Staging counts as production for the two config defaults that differ
 * between development and production (`DL-141`): no login-code driver and no
 * CORS origin unless the box names them.
 */
final class StagingConfigDefaultsTest extends TestCase
{
    private const VARIABLES = ['APP_ENV', 'CORS_ALLOWED_ORIGINS', 'LOGIN_CODE_DRIVER'];

    public function test_staging_defaults_to_no_driver_and_no_origin(): void
    {
        [$driver, $origins] = $this->loadWith('staging');

        $this->assertNull($driver);
        $this->assertSame([], $origins);
    }

    public function test_local_defaults_to_the_fake_driver_and_any_origin(): void
    {
        [$driver, $origins] = $this->loadWith('local');

        $this->assertSame('fake', $driver);
        $this->assertSame(['*'], $origins);
    }

    /**
     * @return array{mixed, mixed}
     */
    private function loadWith(string $environment): array
    {
        $saved = [];

        foreach (self::VARIABLES as $name) {
            $saved[$name] = [
                'env' => array_key_exists($name, $_ENV) ? $_ENV[$name] : null,
                'envSet' => array_key_exists($name, $_ENV),
                'server' => array_key_exists($name, $_SERVER) ? $_SERVER[$name] : null,
                'serverSet' => array_key_exists($name, $_SERVER),
                'getenv' => getenv($name),
            ];
        }

        try {
            foreach (['CORS_ALLOWED_ORIGINS', 'LOGIN_CODE_DRIVER'] as $name) {
                unset($_ENV[$name], $_SERVER[$name]);
                putenv($name);
            }

            $_ENV['APP_ENV'] = $_SERVER['APP_ENV'] = $environment;
            putenv("APP_ENV={$environment}");

            $codes = require base_path('config/login_codes.php');
            $cors = require base_path('config/cors.php');

            return [$codes['driver'], $cors['allowed_origins']];
        } finally {
            foreach ($saved as $name => $was) {
                if ($was['envSet']) {
                    $_ENV[$name] = $was['env'];
                } else {
                    unset($_ENV[$name]);
                }

                if ($was['serverSet']) {
                    $_SERVER[$name] = $was['server'];
                } else {
                    unset($_SERVER[$name]);
                }

                putenv($was['getenv'] === false ? $name : "{$name}={$was['getenv']}");
            }
        }
    }
}
