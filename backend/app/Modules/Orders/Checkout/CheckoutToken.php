<?php

declare(strict_types=1);

namespace App\Modules\Orders\Checkout;

use App\Exceptions\ApiException;
use App\Models\Enums\PaymentMethod;
use App\Models\User;
use Carbon\CarbonImmutable;
use Carbon\CarbonInterface;
use JsonException;
use LogicException;

/**
 * The signed checkout token of `BR-CHK-006` and `DL-37` (4). Stateless: it
 * carries in the clear what order creation needs to rebuild the checkout — the
 * version, the Customer, the cart, the address, the payment method, the
 * delivery wish, the expiry — and the digest of the state the preview showed,
 * all signed with HMAC-SHA256.
 *
 * The key is derived from the application key for this purpose alone, so the
 * signature never shares a key with Laravel's encrypter; rotating the
 * application key makes tokens in flight stale, which costs a new preview.
 * Anything wrong with a token — its shape, its signature, its version, its
 * owner, its age — is the same `409 checkout_snapshot_stale`, and the client
 * previews again.
 */
final class CheckoutToken
{
    public const TTL_SECONDS = 300;

    private const VERSION = 1;

    private const PURPOSE = 'checkout-token/v1';

    public static function issue(CheckoutState $state, CarbonInterface $now): IssuedCheckoutToken
    {
        $expiresAt = CarbonImmutable::instance($now)->addSeconds(self::TTL_SECONDS)->startOfSecond();

        $payload = self::encode(json_encode([
            'v' => self::VERSION,
            'customer' => $state->customer->id,
            'cart' => $state->cart->id,
            'address' => $state->address->id,
            'payment_method' => $state->paymentMethod->value,
            'delivery_time_note' => $state->deliveryTimeNote,
            'exp' => $expiresAt->getTimestamp(),
            'digest' => $state->digest(),
        ], JSON_THROW_ON_ERROR));

        return new IssuedCheckoutToken($payload.'.'.self::encode(self::sign($payload)), $expiresAt);
    }

    /**
     * The claims of a token this Customer may still use.
     */
    public static function read(string $token, User $customer, CarbonInterface $now): CheckoutClaims
    {
        $parts = explode('.', $token);
        if (count($parts) !== 2) {
            throw self::stale();
        }
        [$payload, $signature] = $parts;

        $given = self::decode($signature);
        if ($given === null || ! hash_equals(self::sign($payload), $given)) {
            throw self::stale();
        }

        try {
            $claims = json_decode((string) self::decode($payload), true, 4, JSON_THROW_ON_ERROR);
        } catch (JsonException) {
            throw self::stale();
        }

        if (! is_array($claims)
            || ($claims['v'] ?? null) !== self::VERSION
            || ($claims['customer'] ?? null) !== $customer->id
            || ! is_int($claims['exp'] ?? null)
            || $claims['exp'] <= $now->getTimestamp()) {
            throw self::stale();
        }

        $paymentMethod = PaymentMethod::tryFrom((string) ($claims['payment_method'] ?? ''));
        $note = $claims['delivery_time_note'] ?? null;
        if ($paymentMethod === null
            || ! is_string($claims['cart'] ?? null)
            || ! is_string($claims['address'] ?? null)
            || ! is_string($claims['digest'] ?? null)
            || ($note !== null && ! is_string($note))) {
            throw self::stale();
        }

        return new CheckoutClaims($claims['cart'], $claims['address'], $paymentMethod, $note, $claims['digest']);
    }

    public static function stale(): ApiException
    {
        return ApiException::conflict('checkout_snapshot_stale');
    }

    private static function sign(string $payload): string
    {
        return hash_hmac('sha256', $payload, self::key(), true);
    }

    private static function key(): string
    {
        $appKey = (string) config('app.key');
        if ($appKey === '') {
            throw new LogicException('The application key is not set.');
        }
        if (str_starts_with($appKey, 'base64:')) {
            $appKey = (string) base64_decode(substr($appKey, 7), true);
        }

        return hash_hmac('sha256', self::PURPOSE, $appKey, true);
    }

    private static function encode(string $bytes): string
    {
        return rtrim(strtr(base64_encode($bytes), '+/', '-_'), '=');
    }

    private static function decode(string $text): ?string
    {
        if (preg_match('/^[A-Za-z0-9_-]*\z/', $text) !== 1) {
            return null;
        }

        $bytes = base64_decode(strtr($text, '-_', '+/'), true);

        return $bytes === false ? null : $bytes;
    }
}
