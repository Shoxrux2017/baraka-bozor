<?php

declare(strict_types=1);

/*
|--------------------------------------------------------------------------
| Push notifications
|--------------------------------------------------------------------------
|
| docs/07-architecture.md Section 24 and docs/05-business-rules.md Section 18.
|
| push_driver  which PushSender carries a push: `fake` records it in-process
|              and sends nothing; `fcm` arrives with W4-8.
|
*/

return [
    'push_driver' => env('PUSH_DRIVER', 'fake'),
];
