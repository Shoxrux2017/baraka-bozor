<?php

declare(strict_types=1);

/*
|--------------------------------------------------------------------------
| Trusted proxies
|--------------------------------------------------------------------------
|
| The per-IP rate limit on staff login (docs/09 Section 8) keys on the client
| address. Behind the reverse proxy of docs/07 Section 34 that address is the
| proxy's own unless the proxy is trusted to supply X-Forwarded-For, in which
| case every client would share one counter and twenty wrong attempts from
| anyone would lock staff login for the whole company.
|
| TRUSTED_PROXIES: comma-separated addresses or CIDR ranges of the proxy, or
| "*" only when the application port is reachable from the proxy alone.
| Empty in development, where the client talks to PHP directly.
|
*/

$proxies = env('TRUSTED_PROXIES');

return [
    'proxies' => match (true) {
        ! is_string($proxies), trim($proxies) === '' => null,
        trim($proxies) === '*' => '*',
        default => array_values(array_filter(array_map('trim', explode(',', $proxies)))),
    },
];
