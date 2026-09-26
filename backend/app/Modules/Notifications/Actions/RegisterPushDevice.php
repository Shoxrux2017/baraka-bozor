<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Actions;

use App\Models\Enums\PushPlatform;
use App\Models\PushDevice;
use App\Models\User;

/**
 * Registers the caller's push token (`docs/09` section 27, `DL-17` (9)): one
 * row per token per account, so a phone holding a Customer and a Staff
 * account is notified for both (interview 7.0). A registration of a known
 * token refreshes it — platform, `last_seen_at` — and revives it if it was
 * revoked.
 *
 * One `INSERT … ON CONFLICT` on the `(push_token, user_id)` key, so two
 * registrations racing each other both succeed and leave one row.
 */
final class RegisterPushDevice
{
    public function __invoke(User $user, PushPlatform $platform, #[\SensitiveParameter] string $token): PushDevice
    {
        $now = now();

        PushDevice::query()->upsert(
            [[
                'id' => (new PushDevice)->newUniqueId(),
                'user_id' => $user->id,
                'platform' => $platform->value,
                'push_token' => $token,
                'last_seen_at' => $now,
                'revoked_at' => null,
            ]],
            ['push_token', 'user_id'],
            ['platform', 'last_seen_at', 'revoked_at', 'updated_at'],
        );

        return PushDevice::query()
            ->where('user_id', $user->id)
            ->where('push_token', $token)
            ->firstOrFail();
    }
}
