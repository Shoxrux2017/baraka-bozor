<?php

declare(strict_types=1);

namespace Tests\Support;

use RuntimeException;

/**
 * A throw-away Firebase service account for tests: one RSA-2048 key made once
 * per PHP process, so no real credential is ever needed and the signed JWT can
 * be verified against the public half.
 */
final class FcmTestKey
{
    public const PROJECT = 'bb-test';

    public const CLIENT_EMAIL = 'push@bb-test.iam.gserviceaccount.com';

    public const TOKEN_URI = 'https://oauth2.googleapis.com/token';

    private static ?string $privatePem = null;

    private static ?string $publicPem = null;

    /**
     * @return array<string, string>
     */
    public static function serviceAccount(): array
    {
        return [
            'type' => 'service_account',
            'project_id' => self::PROJECT,
            'private_key_id' => 'test-key-id',
            'private_key' => self::privateKey(),
            'client_email' => self::CLIENT_EMAIL,
            'client_id' => '1234567890',
            'token_uri' => self::TOKEN_URI,
        ];
    }

    public static function encoded(): string
    {
        return base64_encode(json_encode(self::serviceAccount(), JSON_THROW_ON_ERROR));
    }

    public static function publicKey(): string
    {
        self::generate();

        return (string) self::$publicPem;
    }

    public static function privateKey(): string
    {
        self::generate();

        return (string) self::$privatePem;
    }

    private static function generate(): void
    {
        if (self::$privatePem !== null) {
            return;
        }

        $key = openssl_pkey_new(['private_key_bits' => 2048, 'private_key_type' => OPENSSL_KEYTYPE_RSA]);

        if ($key === false || ! openssl_pkey_export($key, $private)) {
            throw new RuntimeException('openssl could not make a test key.');
        }

        self::$privatePem = $private;
        self::$publicPem = (string) openssl_pkey_get_details($key)['key'];
    }
}
