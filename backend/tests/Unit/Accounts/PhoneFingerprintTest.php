<?php

declare(strict_types=1);

namespace Tests\Unit\Accounts;

use App\Modules\Accounts\PhoneFingerprint;
use LogicException;
use Tests\TestCase;

/**
 * `DL-96` item 1: a keyed, stable, one-way fingerprint of a phone under its own
 * secret.
 */
final class PhoneFingerprintTest extends TestCase
{
    private const PHONE = '+998901234567';

    private function key(string $seed): string
    {
        return 'base64:'.base64_encode(str_repeat($seed, 32));
    }

    public function test_a_fingerprint_is_keyed_and_stable(): void
    {
        $fingerprint = PhoneFingerprint::of(self::PHONE);

        $this->assertMatchesRegularExpression('/^[0-9a-f]{64}$/', $fingerprint);
        $this->assertSame($fingerprint, PhoneFingerprint::of(self::PHONE));
        $this->assertNotSame(hash('sha256', self::PHONE), $fingerprint);
        $this->assertNotSame($fingerprint, PhoneFingerprint::of('+998901234568'));

        config(['accounts.phone_fingerprint.key' => $this->key('z')]);

        $this->assertNotSame($fingerprint, PhoneFingerprint::of(self::PHONE));
    }

    public function test_the_application_key_does_not_change_a_fingerprint(): void
    {
        $fingerprint = PhoneFingerprint::of(self::PHONE);

        config(['app.key' => $this->key('q')]);

        $this->assertSame($fingerprint, PhoneFingerprint::of(self::PHONE));
    }

    public function test_previous_keys_still_match(): void
    {
        config(['accounts.phone_fingerprint.key' => $this->key('a'), 'accounts.phone_fingerprint.previous_keys' => []]);
        $old = PhoneFingerprint::of(self::PHONE);

        config(['accounts.phone_fingerprint.key' => $this->key('b'), 'accounts.phone_fingerprint.previous_keys' => [$this->key('a')]]);
        $current = PhoneFingerprint::of(self::PHONE);

        $this->assertNotSame($old, $current);
        $this->assertSame([$current, $old], PhoneFingerprint::candidates(self::PHONE));
    }

    public function test_a_previous_key_with_spaces_around_it_matches_after_trimming(): void
    {
        config(['accounts.phone_fingerprint.key' => $this->key('a'), 'accounts.phone_fingerprint.previous_keys' => []]);
        $old = PhoneFingerprint::of(self::PHONE);

        config(['accounts.phone_fingerprint.key' => $this->key('b'), 'accounts.phone_fingerprint.previous_keys' => [' '.$this->key('a').' ']]);

        $this->assertContains($old, PhoneFingerprint::candidates(self::PHONE));
    }

    public function test_an_unset_key_fails_closed(): void
    {
        config(['accounts.phone_fingerprint.key' => null]);

        $this->expectException(LogicException::class);

        PhoneFingerprint::of(self::PHONE);
    }

    public function test_an_empty_key_fails_closed(): void
    {
        config(['accounts.phone_fingerprint.key' => '']);

        $this->expectException(LogicException::class);

        PhoneFingerprint::of(self::PHONE);
    }

    public function test_a_key_that_is_not_base64_fails_closed(): void
    {
        config(['accounts.phone_fingerprint.key' => 'base64:not base64 !!']);

        $this->expectException(LogicException::class);

        PhoneFingerprint::of(self::PHONE);
    }

    public function test_a_key_of_another_length_fails_closed(): void
    {
        config(['accounts.phone_fingerprint.key' => 'base64:'.base64_encode(str_repeat('k', 16))]);

        $this->expectException(LogicException::class);

        PhoneFingerprint::of(self::PHONE);
    }

    public function test_a_malformed_previous_key_fails_closed(): void
    {
        config(['accounts.phone_fingerprint.previous_keys' => ['base64:c2hvcnQ=']]);

        $this->expectException(LogicException::class);

        PhoneFingerprint::candidates(self::PHONE);
    }
}
