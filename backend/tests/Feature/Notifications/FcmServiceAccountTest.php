<?php

declare(strict_types=1);

namespace Tests\Feature\Notifications;

use App\Modules\Notifications\Push\FcmServiceAccount;
use PHPUnit\Framework\Attributes\DataProvider;
use RuntimeException;
use Tests\Support\FcmTestKey;
use Tests\TestCase;

/**
 * The service-account setting: a valid key gives its project, every defect is
 * named without echoing the value.
 */
final class FcmServiceAccountTest extends TestCase
{
    public function test_a_valid_key_gives_its_project(): void
    {
        $account = FcmServiceAccount::fromConfig(FcmTestKey::encoded());

        $this->assertSame('bb-test', $account->projectId);
        $this->assertSame(FcmTestKey::CLIENT_EMAIL, $account->key()['client_email']);
    }

    /**
     * @return array<string, array{0: mixed}>
     */
    public static function defects(): array
    {
        $without = static function (string $field): string {
            $key = FcmTestKey::serviceAccount();
            unset($key[$field]);

            return base64_encode(json_encode($key, JSON_THROW_ON_ERROR));
        };
        $with = static fn (string $field, string $value): string => base64_encode(json_encode(
            [$field => $value] + FcmTestKey::serviceAccount(),
            JSON_THROW_ON_ERROR,
        ));

        return [
            'null' => [null],
            'empty' => [''],
            'not base64' => ['%%%not-base64'],
            'not json' => [base64_encode('not json')],
            'json list' => [base64_encode('["a","b"]')],
            'wrong type' => [$with('type', 'authorized_user')],
            'no project' => [$without('project_id')],
            'no client email' => [$without('client_email')],
            'no private key' => [$without('private_key')],
            'garbage private key' => [$with('private_key', 'garbage')],
        ];
    }

    #[DataProvider('defects')]
    public function test_each_defect_is_named_without_the_value(mixed $encoded): void
    {
        try {
            FcmServiceAccount::fromConfig($encoded);
            $this->fail('A defective setting must throw.');
        } catch (RuntimeException $e) {
            $this->assertStringContainsString('FCM_SERVICE_ACCOUNT', $e->getMessage());

            if (is_string($encoded) && $encoded !== '') {
                $this->assertStringNotContainsString($encoded, $e->getMessage());
            }

            foreach (explode("\n", FcmTestKey::privateKey()) as $line) {
                if (strlen($line) > 10) {
                    $this->assertStringNotContainsString($line, $e->getMessage());
                }
            }
        }
    }
}
