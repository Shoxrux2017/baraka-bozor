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
|              in a test-only in-process sink; `telegram` sends through
|              Telegram Gateway (needs TELEGRAM_GATEWAY_TOKEN); `sms` arrives
|              with Wave 5.
| test_phones  phone numbers that never receive a code and verify with
|              `test_code` instead. Empty in production. This is server
|              configuration on purpose: an Admin-editable list would be a
|              login bypass one compromised Admin account away (DL-7).
| test_code    the six-digit code those phones accept.
| reviewer_phone, reviewer_code
|              the store reviewer's phone and its own fixed code (DL-105). The
|              one phone allowed in production; both or neither; the code is
|              six digits, not guessable and different from `test_code`. A
|              Customer only: no staff account may sit on the phone.
| daily_limit  paid Telegram checks per Tashkent day for phones with no active
|              account; beyond it such a phone is refused with
|              `provider_unavailable` (DL-104). Phones with an account and
|              test phones never count.
|
*/

$testPhones = env('LOGIN_CODE_TEST_PHONES');

return [
    // The fake is the default everywhere except production, which must name
    // its driver: a production box missing the variable must not deliver
    // nothing in silence. An unset APP_ENV counts as production, as it does
    // for the framework.
    'driver' => env('LOGIN_CODE_DRIVER', env('APP_ENV', 'production') === 'production' ? null : 'fake'),

    'test_phones' => is_string($testPhones) && trim($testPhones) !== ''
        ? array_values(array_filter(array_map('trim', explode(',', $testPhones))))
        : [],

    'test_code' => env('LOGIN_CODE_TEST_CODE'),

    'reviewer_phone' => env('LOGIN_CODE_REVIEWER_PHONE'),

    'reviewer_code' => env('LOGIN_CODE_REVIEWER_CODE'),

    'daily_limit' => env('LOGIN_CODE_DAILY_LIMIT', 500),
];
