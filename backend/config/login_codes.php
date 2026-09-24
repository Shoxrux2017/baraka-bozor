<?php

declare(strict_types=1);

/*
|--------------------------------------------------------------------------
| Customer login codes
|--------------------------------------------------------------------------
|
| docs/07-architecture.md Section 8 and docs/09-api-contracts.md Section 6.
|
| driver       which CodeDeliveryGateway carries the code: `fake` records it
|              in a test-only in-process sink; `telegram` and `sms` arrive
|              with Waves 4 and 5.
| test_phones  phone numbers that never receive a code and verify with
|              `test_code` instead. Empty in production. This is server
|              configuration on purpose: an Admin-editable list would be a
|              login bypass one compromised Admin account away (DL-7).
| test_code    the six-digit code those phones accept.
|
*/

$testPhones = env('LOGIN_CODE_TEST_PHONES');

return [
    // The fake is the default everywhere except production, which must name
    // its driver: a production box missing the variable must not deliver
    // nothing in silence.
    'driver' => env('LOGIN_CODE_DRIVER', env('APP_ENV') === 'production' ? null : 'fake'),

    'test_phones' => is_string($testPhones) && trim($testPhones) !== ''
        ? array_values(array_filter(array_map('trim', explode(',', $testPhones))))
        : [],

    'test_code' => env('LOGIN_CODE_TEST_CODE'),
];
