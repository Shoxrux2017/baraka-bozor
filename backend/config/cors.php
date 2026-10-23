<?php

declare(strict_types=1);

/*
|--------------------------------------------------------------------------
| Cross-origin resource sharing
|--------------------------------------------------------------------------
|
| Only the API is reachable from a browser on another origin: the Flutter web
| panel (docs/07 Section 8, DL-104 (4)). The API authenticates with bearer
| tokens and sets no cookies, so credentials are never shared across origins
| and any other site's script holds no ambient authority to abuse.
|
| allowed_origins   CORS_ALLOWED_ORIGINS: comma-separated origins. Defaults to
|                   "*" everywhere except production, which must name the
|                   panel's origin: a production box missing the variable
|                   allows no origin rather than every one (an unset
|                   APP_ENV counts as production, as it does for the framework).
| exposed_headers   Retry-After: the panel reads it for its countdown after a
|                   429, and a browser hides it from a cross-origin script
|                   unless it is exposed.
| max_age           7200, the longest preflight cache Chrome honours.
|
*/

$origins = env('CORS_ALLOWED_ORIGINS', env('APP_ENV', 'production') === 'production' ? null : '*');

return [
    'paths' => ['api/*'],

    'allowed_methods' => ['*'],

    'allowed_origins' => is_string($origins) && trim($origins) !== ''
        ? array_values(array_filter(array_map('trim', explode(',', $origins))))
        : [],

    'allowed_origins_patterns' => [],

    'allowed_headers' => ['*'],

    'exposed_headers' => ['Retry-After'],

    'max_age' => 7200,

    'supports_credentials' => false,
];
