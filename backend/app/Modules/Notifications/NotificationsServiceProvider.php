<?php

declare(strict_types=1);

namespace App\Modules\Notifications;

use App\Modules\Notifications\Push\FakePushSender;
use App\Modules\Notifications\Push\PushSender;
use Illuminate\Contracts\Foundation\Application;
use Illuminate\Support\ServiceProvider;
use RuntimeException;

/**
 * Wires the notifications module: the push port and its driver.
 *
 * Collected by the module provider registry; nothing lists this class by hand.
 */
final class NotificationsServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        $this->app->singleton(
            FakePushSender::class,
            static fn (Application $app): FakePushSender => new FakePushSender($app->environment('testing')),
        );

        $this->app->singleton(PushSender::class, static function (Application $app): PushSender {
            $driver = config('notifications.push_driver');

            return match ($driver) {
                'fake' => $app->make(FakePushSender::class),
                // `fcm` arrives with W4-8.
                default => throw new RuntimeException(
                    'PUSH_DRIVER is '.json_encode($driver).'; only "fake" exists yet.'
                ),
            };
        });
    }
}
