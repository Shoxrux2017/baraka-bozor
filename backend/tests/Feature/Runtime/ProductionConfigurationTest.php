<?php

declare(strict_types=1);

namespace Tests\Feature\Runtime;

use App\Modules\Notifications\Push\PushSender;
use App\Providers\AppServiceProvider;
use App\Support\Runtime\ProductionConfiguration;
use Illuminate\Routing\Router;
use PHPUnit\Framework\Attributes\DataProvider;
use RuntimeException;
use Tests\Support\FcmTestKey;
use Tests\TestCase;

/**
 * The production boot check (`DL-107`): each missing or unsafe setting is
 * named, no value is ever printed (`AGENTS.md` §5).
 */
final class ProductionConfigurationTest extends TestCase
{
    protected function setUp(): void
    {
        parent::setUp();

        config([
            'app.key' => 'base64:'.base64_encode(str_repeat('k', 32)),
            'app.debug' => false,
            'app.url' => 'https://api.example.test',
            'database.connections.pgsql.password' => 'db-secret-value',
            'login_codes.driver' => 'telegram',
            'services.telegram_gateway.token' => 'tg-test-token',
            'cors.allowed_origins' => ['https://panel.example.test'],
            'trustedproxy.proxies' => ['172.30.250.0/28'],
            'notifications.push_driver' => 'fcm',
            'services.fcm.service_account' => FcmTestKey::encoded(),
        ]);
        $this->app->forgetInstance(PushSender::class);
    }

    public function test_a_complete_configuration_passes(): void
    {
        $this->assertSame([], ProductionConfiguration::problems());

        ProductionConfiguration::assertComplete($this->app);
    }

    /**
     * @return array<string, array{string, mixed, string}>
     */
    public static function gaps(): array
    {
        return [
            'empty key' => ['app.key', '', 'APP_KEY'],
            'debug on' => ['app.debug', true, 'APP_DEBUG'],
            'empty password' => ['database.connections.pgsql.password', '', 'DB_PASSWORD'],
            'no driver' => ['login_codes.driver', null, 'LOGIN_CODE_DRIVER'],
            'fake driver' => ['login_codes.driver', 'fake', 'LOGIN_CODE_DRIVER'],
            'no push driver' => ['notifications.push_driver', null, 'PUSH_DRIVER'],
            'fake push driver' => ['notifications.push_driver', 'fake', 'PUSH_DRIVER'],
            'empty url' => ['app.url', '', 'APP_URL'],
            'http url' => ['app.url', 'http://api.example.test', 'APP_URL'],
            'two origins' => ['cors.allowed_origins', ['https://a.example.test', 'https://b.example.test'], 'CORS_ALLOWED_ORIGINS'],
            'no origins' => ['cors.allowed_origins', [], 'CORS_ALLOWED_ORIGINS'],
            'wildcard origin' => ['cors.allowed_origins', ['*'], 'CORS_ALLOWED_ORIGINS'],
            'no proxies' => ['trustedproxy.proxies', null, 'TRUSTED_PROXIES'],
            'no fingerprint key' => ['accounts.phone_fingerprint.key', null, 'PHONE_FINGERPRINT_KEY'],
        ];
    }

    #[DataProvider('gaps')]
    public function test_each_gap_is_named(string $key, mixed $value, string $name): void
    {
        config([$key => $value]);

        $this->assertSame([$name], ProductionConfiguration::problems());

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage($name);

        ProductionConfiguration::assertComplete($this->app);
    }

    public function test_the_message_never_carries_a_value(): void
    {
        config(['app.debug' => true, 'app.key' => '']);

        try {
            ProductionConfiguration::assertComplete($this->app);
            $this->fail('The incomplete configuration was accepted.');
        } catch (RuntimeException $e) {
            $this->assertStringContainsString('APP_DEBUG', $e->getMessage());
            $this->assertStringContainsString('APP_KEY', $e->getMessage());
            $this->assertStringNotContainsString('db-secret-value', $e->getMessage());
        }
    }

    public function test_the_telegram_driver_without_a_token_is_named(): void
    {
        config(['login_codes.driver' => 'telegram', 'services.telegram_gateway.token' => '']);

        $this->assertSame(['TELEGRAM_GATEWAY_TOKEN'], ProductionConfiguration::problems());

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('TELEGRAM_GATEWAY_TOKEN');

        ProductionConfiguration::assertComplete($this->app);
    }

    public function test_the_telegram_driver_with_a_token_passes(): void
    {
        config(['login_codes.driver' => 'telegram', 'services.telegram_gateway.token' => 'tg-test-token']);
        $this->assertSame([], ProductionConfiguration::problems());
        ProductionConfiguration::assertComplete($this->app);
    }

    /**
     * @return array<string, array{mixed, bool}>
     */
    public static function dailyLimits(): array
    {
        return [
            'zero' => [0, true],
            'negative' => [-1, true],
            'text' => ['abc', true],
            'five hundred' => [500, false],
            'default' => [null, false],
        ];
    }

    #[DataProvider('dailyLimits')]
    public function test_the_daily_limit_must_be_a_positive_integer(mixed $value, bool $named): void
    {
        config(['login_codes.daily_limit' => $value ?? config('login_codes.daily_limit')]);

        $this->assertSame($named ? ['LOGIN_CODE_DAILY_LIMIT'] : [], ProductionConfiguration::problems());
    }

    public function test_an_unknown_driver_fails_at_the_check(): void
    {
        config(['login_codes.driver' => 'carrier-pigeon']);

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('LOGIN_CODE_DRIVER');

        ProductionConfiguration::assertComplete($this->app);
    }

    public function test_the_fcm_driver_without_a_key_is_named(): void
    {
        config(['services.fcm.service_account' => '']);

        $this->assertSame(['FCM_SERVICE_ACCOUNT'], ProductionConfiguration::problems());

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('FCM_SERVICE_ACCOUNT');

        ProductionConfiguration::assertComplete($this->app);
    }

    public function test_a_malformed_key_fails_at_the_check(): void
    {
        config(['services.fcm.service_account' => base64_encode('{}')]);
        $this->app->forgetInstance(PushSender::class);

        $this->assertSame([], ProductionConfiguration::problems());

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('FCM_SERVICE_ACCOUNT');

        ProductionConfiguration::assertComplete($this->app);
    }

    public function test_an_unknown_push_driver_fails_at_the_check(): void
    {
        config(['notifications.push_driver' => 'pigeon']);
        $this->app->forgetInstance(PushSender::class);

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('PUSH_DRIVER');

        ProductionConfiguration::assertComplete($this->app);
    }

    public function test_the_boot_runs_the_check_in_production_only(): void
    {
        config(['app.key' => '']);
        $provider = new AppServiceProvider($this->app);
        $original = $this->app['env'];

        try {
            $this->app['env'] = 'testing';
            $provider->boot($this->app->make(Router::class));

            $this->app['env'] = 'production';
            $this->expectException(RuntimeException::class);
            $this->expectExceptionMessage('APP_KEY');
            $provider->boot($this->app->make(Router::class));
        } finally {
            $this->app['env'] = $original;
        }
    }

    public function test_package_discovery_is_not_checked(): void
    {
        config(['app.key' => '']);
        $provider = new AppServiceProvider($this->app);
        $originalEnv = $this->app['env'];
        $originalArgv = $_SERVER['argv'] ?? null;

        try {
            $this->app['env'] = 'production';

            $_SERVER['argv'] = ['artisan', 'package:discover'];
            $provider->boot($this->app->make(Router::class));

            $_SERVER['argv'] = ['artisan', 'optimize'];
            try {
                $provider->boot($this->app->make(Router::class));
                $this->fail('The incomplete configuration was accepted.');
            } catch (RuntimeException $e) {
                $this->assertStringContainsString('APP_KEY', $e->getMessage());
            }
        } finally {
            $this->app['env'] = $originalEnv;
            $_SERVER['argv'] = $originalArgv;
        }
    }
}
