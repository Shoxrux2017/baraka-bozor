<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Push;

use RuntimeException;

/**
 * The Firebase service-account key behind `FCM_SERVICE_ACCOUNT`, read from its
 * base64 form (`DL-104`). A defect throws a `RuntimeException` that names the
 * setting and the check that failed, never a value: the key is a credential.
 */
final class FcmServiceAccount
{
    /**
     * @param  array<string, string>  $key
     */
    private function __construct(
        public readonly string $projectId,
        #[\SensitiveParameter]
        private readonly array $key,
    ) {}

    public static function fromConfig(#[\SensitiveParameter] mixed $encoded): self
    {
        if (! is_string($encoded) || trim($encoded) === '') {
            self::fail('is not set');
        }

        $json = base64_decode(trim($encoded), true);

        if ($json === false) {
            self::fail('is not valid base64');
        }

        $key = json_decode($json, true);

        if (! is_array($key) || array_is_list($key)) {
            self::fail('does not hold a JSON object');
        }

        if (($key['type'] ?? null) !== 'service_account') {
            self::fail('is not a service_account key');
        }

        foreach (['project_id', 'client_email', 'private_key'] as $field) {
            if (! is_string($key[$field] ?? null) || $key[$field] === '') {
                self::fail('has no '.$field);
            }
        }

        if (openssl_pkey_get_private($key['private_key']) === false) {
            self::fail('has a private_key that cannot be read');
        }

        /** @var array<string, string> $key */
        return new self($key['project_id'], $key);
    }

    /**
     * The decoded key, in the shape google/auth reads.
     *
     * @return array<string, string>
     */
    public function key(): array
    {
        return $this->key;
    }

    private static function fail(string $check): never
    {
        throw new RuntimeException('FCM_SERVICE_ACCOUNT '.$check.'.');
    }
}
