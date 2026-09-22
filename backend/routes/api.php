<?php

/*
|--------------------------------------------------------------------------
| Client API routes
|--------------------------------------------------------------------------
|
| Mounted under /api/v1 by bootstrap/app.php. This file declares no endpoint of
| its own: each module declares its endpoints in routes/api/v1/<module>.php and
| the loader below requires them all, in sorted filename order.
|
| That is decision D-8 of the execution-model design record. It exists so that
| concurrent tracks never edit one shared route file — a feature task adds its
| own module file and leaves this one alone. A module file must not repeat the
| /api/v1 prefix; bootstrap/app.php already applies it.
|
| TEMPORARY DIAGNOSTIC, restored in the next commit. The loader call and its
| import are removed for exactly one CI run, to establish whether executing the
| loader during Larastan's application bootstrap is what kills a PHPStan
| parallel worker in CI while five consecutive local runs pass.
|
| use App\Support\Routing\ModuleRouteLoader;
| ModuleRouteLoader::load(__DIR__.'/api/v1');
|
*/
