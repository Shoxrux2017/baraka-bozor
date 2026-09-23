<?php

declare(strict_types=1);

namespace Tests\Fixtures\Modules\Alpha;

use Illuminate\Support\ServiceProvider;
use Tests\Fixtures\Modules\RegistrationLog;

/**
 * A stand-in for a real module's provider.
 *
 * It binds something the test can resolve, so that registration is proven by the
 * container answering rather than by the registry being inspected.
 */
final class AlphaServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        RegistrationLog::record('Alpha');

        $this->app->instance('module.alpha', 'alpha');
    }
}
