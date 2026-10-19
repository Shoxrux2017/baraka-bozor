<?php

declare(strict_types=1);

namespace App\Modules\Auth;

use App\Modules\Auth\Models\LoginChallenge;
use Illuminate\Cache\RateLimiter;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

/**
 * Checks a login code of one purpose against the newest open challenge of the
 * phone and consumes it (`BR-ROLE-012`). Sign-in and account deletion share
 * this check, so they share the phone's attempt count and lock (`DL-88`,
 * `DL-94` item 3).
 */
final class LoginCodeCheck
{
    public function __construct(private readonly RateLimiter $limiter) {}

    /**
     * @throws LoginCodeRefused
     */
    public function consume(string $phone, #[\SensitiveParameter] string $code, string $purpose): void
    {
        // First, before the challenge is read: a locked phone tells nothing
        // about its code, not even the right one (`DL-88`).
        $lockKey = LoginCodePolicy::lockKey($phone);
        if ($this->limiter->tooManyAttempts($lockKey, 1)) {
            throw new LoginCodeRefused('code_locked', $this->limiter->availableIn($lockKey));
        }

        /** @var LoginCodeRefused|null $refusal */
        $refusal = null;
        // A refusal is thrown only after the transaction has committed: the
        // failed-attempt count and the consumption of the code must persist,
        // and an exception escaping the closure would roll them back.
        DB::transaction(function () use ($phone, $code, $purpose, &$refusal): void {
            try {
                $this->check($phone, $code, $purpose);
            } catch (LoginCodeRefused $exception) {
                $refusal = $exception;
            }
        });

        if ($refusal !== null) {
            // The third wrong code locks the phone, now that the count is
            // committed.
            if ($refusal->apiCode === 'code_locked') {
                $this->limiter->hit($lockKey, LoginCodePolicy::LOCK_SECONDS);
            }

            throw $refusal;
        }
    }

    private function check(string $phone, #[\SensitiveParameter] string $code, string $purpose): void
    {
        $challenge = LoginChallenge::query()
            ->openFor($phone, $purpose)
            ->orderByDesc('created_at')
            ->lockForUpdate()
            ->first();

        if ($challenge === null) {
            throw new LoginCodeRefused('code_invalid');
        }

        if ($challenge->isExpired()) {
            throw new LoginCodeRefused('code_expired');
        }

        if ($challenge->failed_attempts >= LoginCodePolicy::MAX_FAILED_ATTEMPTS) {
            throw new LoginCodeRefused('code_attempts_exhausted');
        }

        if (! Hash::check($code, $challenge->code_hash)) {
            $challenge->forceFill(['failed_attempts' => $challenge->failed_attempts + 1])->save();

            // The attempt that reaches the limit is answered as the lock; the
            // lock itself is taken after the commit.
            if ($challenge->failed_attempts >= LoginCodePolicy::MAX_FAILED_ATTEMPTS) {
                throw new LoginCodeRefused('code_locked', LoginCodePolicy::LOCK_SECONDS);
            }

            throw new LoginCodeRefused('code_invalid');
        }

        // Consumed before the caller looks at any account, so a valid code
        // opens nothing twice — not even for a blocked account.
        $challenge->forceFill(['consumed_at' => now()])->save();
    }
}
