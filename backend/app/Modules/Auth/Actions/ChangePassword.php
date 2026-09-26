<?php

declare(strict_types=1);

namespace App\Modules\Auth\Actions;

use App\Exceptions\ApiException;
use App\Models\User;
use Illuminate\Cache\RateLimiter;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Laravel\Sanctum\PersonalAccessToken;

/**
 * Staff password change, `docs/09-api-contracts.md` Section 10.
 *
 * The new password has already passed validation when this runs, so a
 * rejected new password never reaches the current-password check and never
 * counts. Five failed checks per bearer token per minute: keyed to the token,
 * not the account, because keyed to the account the holder of a stolen token
 * could keep the counter saturated and bar the owner from the one action that
 * takes the credential away from them.
 *
 * A successful change clears the first-login gate and revokes every other
 * token of the account (`DL-9`): whoever held one now needs the new password.
 */
final class ChangePassword
{
    public const ATTEMPTS = 5;

    public const DECAY_SECONDS = 60;

    public function __construct(private readonly RateLimiter $limiter) {}

    public function __invoke(User $user, PersonalAccessToken $token, #[\SensitiveParameter] string $currentPassword, #[\SensitiveParameter] string $newPassword): void
    {
        $key = "change-password:token:{$token->getKey()}";

        if ($this->limiter->tooManyAttempts($key, self::ATTEMPTS)) {
            throw ApiException::rateLimited($this->limiter->availableIn($key));
        }

        if (! Hash::check($currentPassword, (string) $user->password)) {
            $this->limiter->hit($key, self::DECAY_SECONDS);

            throw ApiException::unauthenticated('invalid_credentials');
        }

        DB::transaction(function () use ($user, $token, $newPassword): void {
            // The model's `hashed` cast stores the hash; the plaintext never
            // reaches the database.
            $user->forceFill([
                'password' => $newPassword,
                'must_change_password' => false,
                'password_changed_at' => now(),
            ])->save();

            $user->tokens()->whereKeyNot($token->getKey())->delete();
        });

        $this->limiter->clear($key);
    }
}
