<?php

declare(strict_types=1);

namespace App\Modules\Orders\Checkout;

use LogicException;

/**
 * The keys a checkout token is made with, each derived from the application
 * key for one purpose, so neither is ever the key of Laravel's encrypter or of
 * the other (`DL-41` (7)).
 *
 * A key that cannot be read fails closed: an empty or undecodable `APP_KEY`
 * throws rather than signing with an empty key, which anyone could forge.
 */
final class CheckoutSecrets
{
    public const SIGNING = 'checkout-token/v1';

    public const DIGEST = 'checkout-digest/v1';

    public static function key(string $purpose): string
    {
        $appKey = (string) config('app.key');

        if (str_starts_with($appKey, 'base64:')) {
            $appKey = base64_decode(substr($appKey, 7), true);
            if ($appKey === false) {
                throw new LogicException('The application key is not valid base64.');
            }
        }

        if ($appKey === '') {
            throw new LogicException('The application key is not set.');
        }

        return hash_hmac('sha256', $purpose, $appKey, true);
    }
}
