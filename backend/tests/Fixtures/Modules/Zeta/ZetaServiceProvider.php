<?php

declare(strict_types=1);

namespace Tests\Fixtures\Modules\Zeta;

use Illuminate\Support\ServiceProvider;
use Tests\Fixtures\Modules\RegistrationLog;

/**
 * A stand-in for a real module's provider.
 *
 * It binds something the test can resolve, so that registration is proven by the
 * container answering rather than by the registry being inspected.
 */
final class ZetaServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        RegistrationLog::record('Zeta');

        $this->app->instance('module.zeta', 'zeta');
    }
}
