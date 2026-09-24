<?php

declare(strict_types=1);

namespace App\Modules\Auth\Sanctum;

use DateTimeInterface;
use Illuminate\Support\Carbon;
use Laravel\Sanctum\PersonalAccessToken;

/**
 * The sliding token lifetime of `docs/07-architecture.md` Section 8.
 *
 * A token is alive while its last use — or its creation, when it was never
 * used — is less than 30 days ago. Sanctum's own `expiration` setting counts
 * from issue and stays unset: an active Shopper must never be signed out
 * mid-order, while a lost phone stops working within a month.
 */
final class TokenLifetime
{
    public const DAYS = 30;

    public static function isAlive(PersonalAccessToken $token): bool
    {
        $lastActivity = $token->last_used_at ?? $token->created_at;

        if (! $lastActivity instanceof DateTimeInterface) {
            // A token with no instant at all cannot prove it was used recently.
            return false;
        }

        return Carbon::instance($lastActivity)->gt(Carbon::now()->subDays(self::DAYS));
    }
}
