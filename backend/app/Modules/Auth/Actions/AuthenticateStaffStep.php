<?php

declare(strict_types=1);

namespace App\Modules\Auth\Actions;

use App\Exceptions\ApiException;
use App\Models\Enums\UserStatus;
use App\Modules\Auth\Models\StaffLoginStep;
use App\Support\Http\ClientAddress;
use Illuminate\Cache\RateLimiter;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

/**
 * `POST /auth/staff/step` — docs/09 Section 8, `DL-77`.
 *
 * Redeems the step a verified login code handed out, with the staff password.
 * The step is single use: a right password consumes it, a wrong one counts an
 * attempt, and the fifth wrong password exhausts it. A blocked account with
 * the right password is answered `account_blocked` and the step is spent.
 *
 * Twenty refusals per IP per minute bound one source guessing step tokens.
 */
final class AuthenticateStaffStep
{
    public const IP_ATTEMPTS = 20;

    public const DECAY_SECONDS = 60;

    public function __construct(private readonly RateLimiter $limiter) {}

    public function __invoke(
        #[\SensitiveParameter] string $stepToken,
        #[\SensitiveParameter] string $password,
        string $ip,
    ): IssuedSession {
        $ipKey = 'staff-step:ip:'.ClientAddress::limiterKey($ip);

        if ($this->limiter->tooManyAttempts($ipKey, self::IP_ATTEMPTS)) {
            throw ApiException::rateLimited($this->limiter->availableIn($ipKey));
        }

        /** @var ApiException|null $refusal */
        $refusal = null;

        // A refusal is thrown only after the transaction has committed: the
        // attempt count and the consumption of the step must persist.
        $session = DB::transaction(function () use ($stepToken, $password, &$refusal): ?IssuedSession {
            try {
                return $this->redeem($stepToken, $password);
            } catch (ApiException $exception) {
                $refusal = $exception;

                return null;
            }
        });

        if ($refusal !== null) {
            $this->limiter->hit($ipKey, self::DECAY_SECONDS);

            throw $refusal;
        }

        // The closure returns null only alongside a refusal.
        assert($session instanceof IssuedSession);

        return $session;
    }

    private function redeem(#[\SensitiveParameter] string $stepToken, #[\SensitiveParameter] string $password): IssuedSession
    {
        $step = StaffLoginStep::query()
            ->where('token_hash', hash('sha256', $stepToken))
            ->lockForUpdate()
            ->first();

        if ($step === null
            || $step->consumed_at !== null
            || $step->failed_attempts >= StaffLoginStep::MAX_FAILED_ATTEMPTS) {
            throw ApiException::unauthenticated('staff_step_invalid');
        }

        if ($step->isExpired()) {
            throw ApiException::unauthenticated('staff_step_expired');
        }

        $staff = $step->staff()->firstOrFail();

        if ($staff->password === null || ! Hash::check($password, $staff->password)) {
            $step->forceFill(['failed_attempts' => $step->failed_attempts + 1])->save();

            throw ApiException::unauthenticated('invalid_credentials');
        }

        $step->forceFill(['consumed_at' => now()])->save();

        if ($staff->status === UserStatus::Blocked) {
            throw ApiException::unauthenticated('account_blocked');
        }

        $staff->forceFill(['last_login_at' => now()])->save();

        return new IssuedSession($staff->createToken('staff')->plainTextToken, $staff);
    }
}
