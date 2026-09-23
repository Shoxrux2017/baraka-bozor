<?php

declare(strict_types=1);

namespace Tests\Fixtures\Modules\Beta;

use Illuminate\Support\ServiceProvider;
use Tests\Fixtures\Modules\RegistrationLog;

/**
 * A stand-in for a real module's provider.
 *
 * It binds something the test can resolve, so that registration is proven by the
 * container answering rather than by the registry being inspected.
 */
final class BetaServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        RegistrationLog::record('Beta');

        $this->app->instance('module.beta', 'beta');
    }
}
