<?php

declare(strict_types=1);

namespace Tests\Unit\Support;

use App\Support\Http\ClientAddress;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;

final class ClientAddressTest extends TestCase
{
    /**
     * @return array<string, array{string, string}>
     */
    public static function addresses(): array
    {
        return [
            'ipv4 as given' => ['203.0.113.7', '203.0.113.7'],
            'ipv6 to its /64' => ['2001:db8:1:2:3:4:5:6', '2001:db8:1:2::/64'],
            'ipv6 upper case, same /64' => ['2001:DB8:1:2:ffff::1', '2001:db8:1:2::/64'],
            'ipv6 next /64' => ['2001:db8:1:3::1', '2001:db8:1:3::/64'],
            'ipv4-mapped ipv6 to its ipv4' => ['::ffff:203.0.113.7', '203.0.113.7'],
            'empty as given' => ['', ''],
            'unreadable as given' => ['not-an-ip', 'not-an-ip'],
        ];
    }

    #[DataProvider('addresses')]
    public function test_limiter_key(string $ip, string $expected): void
    {
        $this->assertSame($expected, ClientAddress::limiterKey($ip));
    }
}
