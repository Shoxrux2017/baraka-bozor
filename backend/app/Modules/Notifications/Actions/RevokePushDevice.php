<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Actions;

use App\Models\PushDevice;
use App\Models\User;
use App\Support\Scope\ScopedLookup;
use Carbon\CarbonInterface;
use Illuminate\Database\Eloquent\Builder;

/**
 * Revokes one of the caller's devices (`docs/09` section 27, `DL-26` (3)).
 *
 * One conditional statement does it, so two revokes racing each other, or a
 * revoke racing a re-registration that has just revived the device, cannot
 * overwrite the first instant or re-revoke what the registration revived:
 * only a live row of the caller's is touched. When no row was touched, the
 * scoped lookup tells an already revoked device of the caller's (a repeat,
 * `204`) from anything else (the scope-safe `404`).
 */
final class RevokePushDevice
{
    public function __invoke(User $user, string $deviceId): void
    {
        $revoked = self::own($user)
            ->whereKey($deviceId)
            ->whereNull('revoked_at')
            ->update(['revoked_at' => now(), 'updated_at' => now()]);

        if ($revoked === 0) {
            ScopedLookup::firstOrNotFound(self::own($user)->whereKey($deviceId));
        }
    }

    /**
     * Every live device of [$user], at once: what blocking an account or
     * resetting its password does, so a phone that has lost its sessions
     * stops receiving the account's pushes too (`DL-26` (5)).
     */
    public static function everyDeviceOf(User $user): void
    {
        self::own($user)
            ->whereNull('revoked_at')
            ->update(['revoked_at' => now(), 'updated_at' => now()]);
    }

    /**
     * The provider refused this device's token for good: one conditional
     * statement revokes the live row, so a repeat or a racing revoke changes
     * nothing.
     */
    public static function refusedByProvider(string $deviceId): void
    {
        PushDevice::query()
            ->whereKey($deviceId)
            ->whereNull('revoked_at')
            ->update(['revoked_at' => now(), 'updated_at' => now()]);
    }

    /**
     * Revokes every live device not seen since [$cutoff]; a device never seen
     * counts from the day it was registered. Returns how many it revoked.
     */
    public static function unseenSince(CarbonInterface $cutoff): int
    {
        return PushDevice::query()
            ->whereNull('revoked_at')
            ->whereRaw('coalesce(last_seen_at, created_at) < ?', [$cutoff])
            ->update(['revoked_at' => now(), 'updated_at' => now()]);
    }

    /**
     * @return Builder<PushDevice>
     */
    private static function own(User $user): Builder
    {
        return PushDevice::query()->where('user_id', $user->id);
    }
}
