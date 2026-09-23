<?php

use App\Providers\AppServiceProvider;
use App\Support\Modules\ModuleProviderRegistry;

/*
|--------------------------------------------------------------------------
| Application service providers
|--------------------------------------------------------------------------
|
| This file lists no module of its own. Each module declares its provider at
| app/Modules/<Module>/<Name>ServiceProvider.php and the registry below collects
| them all, in sorted order.
|
| That is decision D-8, the same rule routes/api.php already follows. It exists
| so that concurrent tracks never edit one shared file: a feature task adds its
| own provider inside its own module directory and leaves this one alone. A
| provider added here by hand is exactly the collision the decision prevents,
| and tests/Feature/Modules/ModuleProviderRegistryTest.php fails if one is.
|
*/

return array_merge(
    [AppServiceProvider::class],
    ModuleProviderRegistry::discover(__DIR__.'/../app/Modules', 'App\Modules'),
);
