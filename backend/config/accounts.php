<?php

declare(strict_types=1);

/*
|--------------------------------------------------------------------------
| Accounts
|--------------------------------------------------------------------------
|
| docs/08-database.md Section 35, DL-96 item 1.
|
| phone_fingerprint.key
|                the secret the block list's phone fingerprints are made with:
|                `base64:` and 32 random bytes. Required; a missing or malformed
|                key stops the sign-in instead of weakening the block list.
| phone_fingerprint.previous_keys
|                the keys the fingerprint was made with before, comma-separated
|                in the environment. Never remove a key from this list: a
|                fingerprint cannot be re-made without its phone, so a removed
|                key unblocks every number recorded under it.
|
*/

return [
    'phone_fingerprint' => [
        'key' => env('PHONE_FINGERPRINT_KEY'),
        'previous_keys' => array_values(array_filter(array_map('trim', explode(',', (string) env('PHONE_FINGERPRINT_PREVIOUS_KEYS', ''))))),
    ],
];
