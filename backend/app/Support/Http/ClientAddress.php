<?php

declare(strict_types=1);

namespace App\Support\Http;

/**
 * The key a per-address limit counts a client by. One subscriber holds a whole
 * IPv6 /64, so counting single IPv6 addresses would let one phone rotate past
 * every per-address limit (DL-104 (9)); an IPv6 client is counted by its /64,
 * an IPv4-mapped IPv6 address by its IPv4, an IPv4 address as it is.
 */
final class ClientAddress
{
    public static function limiterKey(string $ip): string
    {
        $packed = @inet_pton($ip);

        if ($packed === false || strlen($packed) !== 16) {
            return $ip;
        }

        if (str_starts_with($packed, str_repeat("\0", 10)."\xff\xff")) {
            return (string) inet_ntop(substr($packed, 12));
        }

        return inet_ntop(substr($packed, 0, 8).str_repeat("\0", 8)).'/64';
    }
}
