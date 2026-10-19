<?php

declare(strict_types=1);

namespace App\Modules\Accounts;

use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * The block list that outlives an erased blocked account (`DL-95`): only a
 * fingerprint of the phone is kept, never the phone.
 */
final class BlockedPhones
{
    public static function block(string $phone, User $erased, User $actor): void
    {
        DB::table('blocked_phone_fingerprints')->insertOrIgnore([
            'fingerprint' => PhoneFingerprint::of($phone),
            'erased_user_id' => $erased->id,
            'created_by_user_id' => $actor->id,
            'created_at' => now(),
        ]);
    }

    public static function isBlocked(string $phone): bool
    {
        return DB::table('blocked_phone_fingerprints')
            ->whereIn('fingerprint', PhoneFingerprint::candidates($phone))
            ->exists();
    }
}
