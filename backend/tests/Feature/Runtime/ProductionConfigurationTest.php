<?php

declare(strict_types=1);

namespace Tests\Feature\Runtime;

use App\Providers\AppServiceProvider;
use App\Support\Runtime\ProductionConfiguration;
use Illuminate\Routing\Router;
use PHPUnit\Framework\Attributes\DataProvider;
use RuntimeException;
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
            'database.connections.pgsql.password' => 'db-secret-value',
            'login_codes.driver' => 'fake',
            'cors.allowed_origins' => ['https://panel.example.test'],
            'trustedproxy.proxies' => ['172.30.250.0/28'],
        ]);
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

    public function test_an_unknown_driver_fails_at_the_check(): void
    {
        config(['login_codes.driver' => 'telegram']);

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('LOGIN_CODE_DRIVER');

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
            $provider->boot($this->app->make(Router::class));
        } finally {
            $this->app['env'] = $original;
        }
    }
}
