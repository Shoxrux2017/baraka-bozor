<?php

declare(strict_types=1);

/*
|--------------------------------------------------------------------------
| Local walkthrough fixtures
|--------------------------------------------------------------------------
|
| database/seeders/WalkthroughSeeder.php, which refuses to run outside the
| local environment (DL-35).
|
| staff_password  the password the seeded staff accounts are created with.
|                 Read from the gitignored .env so that the repository
|                 carries no password.
|
*/

return [
    'staff_password' => env('WALKTHROUGH_STAFF_PASSWORD'),
];
