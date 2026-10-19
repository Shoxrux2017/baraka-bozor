<?php

declare(strict_types=1);

namespace Tests\Unit\Accounts;

use App\Modules\Accounts\PhoneFingerprint;
use LogicException;
use Tests\TestCase;

/**
 * `DL-96` item 1: a keyed, stable, one-way fingerprint of a phone.
 */
final class PhoneFingerprintTest extends TestCase
{
    private const PHONE = '+998901234567';

    private function key(string $seed): string
    {
        return 'base64:'.base64_encode(str_pad($seed, 32, $seed));
    }

    public function test_a_fingerprint_is_keyed_and_stable(): void
    {
        $fingerprint = PhoneFingerprint::of(self::PHONE);

        $this->assertMatchesRegularExpression('/^[0-9a-f]{64}$/', $fingerprint);
        $this->assertSame($fingerprint, PhoneFingerprint::of(self::PHONE));
        $this->assertNotSame(hash('sha256', self::PHONE), $fingerprint);
        $this->assertNotSame($fingerprint, PhoneFingerprint::of('+998901234568'));

        config(['app.key' => $this->key('z')]);

        $this->assertNotSame($fingerprint, PhoneFingerprint::of(self::PHONE));
    }

    public function test_previous_keys_still_match(): void
    {
        config(['app.key' => $this->key('a'), 'app.previous_keys' => []]);
        $old = PhoneFingerprint::of(self::PHONE);

        config(['app.key' => $this->key('b'), 'app.previous_keys' => [$this->key('a')]]);
        $current = PhoneFingerprint::of(self::PHONE);

        $this->assertNotSame($old, $current);
        $this->assertSame([$current, $old], PhoneFingerprint::candidates(self::PHONE));
    }

    public function test_an_unset_key_fails_closed(): void
    {
        config(['app.key' => '']);

        $this->expectException(LogicException::class);

        PhoneFingerprint::of(self::PHONE);
    }
}
