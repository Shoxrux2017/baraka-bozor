<?php

declare(strict_types=1);

namespace App\Modules\Auth\Actions;

use App\Exceptions\ApiException;
use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\User;
use Illuminate\Cache\RateLimiter;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

/**
 * Staff login, `docs/09-api-contracts.md` Section 8.
 *
 * Resolves the active Staff account for the phone — never a Customer account,
 * which has no password — checks the password, and issues a token. A blocked
 * Staff account with the right password is refused as `account_blocked`, so
 * the block cannot be mistaken for a typo; with the wrong password it is
 * `invalid_credentials` like any other miss, so the block is disclosed only
 * to whoever holds the password.
 *
 * Two rate limits bound different attacks: five failures per phone per minute
 * bounds guessing against one known phone, twenty per IP per minute bounds one
 * source walking a list of phones. A successful login clears the phone
 * counter and leaves the IP counter alone, so a legitimate user cannot clear
 * it for an attacker sharing the address. No account lockout: it would let
 * anyone who knows an Admin's phone disable that Admin.
 */
final class AuthenticateStaff
{
    public const PHONE_ATTEMPTS = 5;

    public const IP_ATTEMPTS = 20;

    public const DECAY_SECONDS = 60;

    private static ?string $dummyHash = null;

    public function __construct(private readonly RateLimiter $limiter) {}

    public function __invoke(string $phone, string $password, string $ip): IssuedSession
    {
        $phoneKey = "staff-login:phone:{$phone}";
        $ipKey = "staff-login:ip:{$ip}";

        foreach ([[$phoneKey, self::PHONE_ATTEMPTS], [$ipKey, self::IP_ATTEMPTS]] as [$key, $maxAttempts]) {
            if ($this->limiter->tooManyAttempts($key, $maxAttempts)) {
                throw ApiException::rateLimited($this->limiter->availableIn($key));
            }
        }

        $account = $this->activeStaff($phone) ?? $this->blockedStaff($phone);

        // The hash is checked even when no account exists, so the response
        // time does not say whether the phone is known.
        $hash = $account->password ?? $this->dummyHash();

        if ($account === null || ! Hash::check($password, $hash)) {
            $this->limiter->hit($phoneKey, self::DECAY_SECONDS);
            $this->limiter->hit($ipKey, self::DECAY_SECONDS);

            throw ApiException::unauthenticated('invalid_credentials');
        }

        if ($account->status === UserStatus::Blocked) {
            // Counted like a failure: the caller learns nothing new, since they
            // already hold the password, but repeated probing of a blocked
            // account is still bounded.
            $this->limiter->hit($phoneKey, self::DECAY_SECONDS);
            $this->limiter->hit($ipKey, self::DECAY_SECONDS);

            throw ApiException::unauthenticated('account_blocked');
        }

        $this->limiter->clear($phoneKey);

        $account->forceFill(['last_login_at' => now()])->save();

        return new IssuedSession($account->createToken('staff')->plainTextToken, $account);
    }

    private function activeStaff(string $phone): ?User
    {
        return User::query()
            ->where('phone', $phone)
            ->where('role', '<>', Role::Customer->value)
            ->where('status', UserStatus::Active->value)
            ->first();
    }

    /**
     * The most recently blocked Staff account for the phone, if any.
     */
    private function blockedStaff(string $phone): ?User
    {
        return User::query()
            ->where('phone', $phone)
            ->where('role', '<>', Role::Customer->value)
            ->where('status', UserStatus::Blocked->value)
            ->orderByDesc('blocked_at')
            ->first();
    }

    private function dummyHash(): string
    {
        return self::$dummyHash ??= Hash::make(Str::random(32));
    }
}
