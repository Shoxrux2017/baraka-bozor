<?php

declare(strict_types=1);

namespace App\Modules\Auth;

use App\Exceptions\ApiException;
use App\Models\Enums\UserStatus;
use App\Models\User;
use Illuminate\Cache\RateLimiter;
use Illuminate\Support\Facades\Log;

/**
 * The daily ceiling of paid login-code checks for phones that hold no active
 * account (`DL-104` (9), `docs/09` Section 6).
 *
 * Telegram Gateway charges for a check that confirms the number, and a phone
 * that is not a customer yet costs money without being anyone's sign-in. The ceiling bounds that
 * spending for a day counted in Tashkent time. A phone with an active account,
 * of any role, is never counted and never refused by it, so existing people can
 * always sign in or erase their account.
 *
 * Its price: while the ceiling holds, the refusal tells a phone with no account
 * from a phone with one (`docs/09` Section 6). The counter is taken before the
 * gateway call, as every login-code counter is (`DL-11` (1)), so it also counts
 * checks that Telegram did not charge; it errs toward spending less. A warning
 * at half and at the ceiling is a log line that an external check or a log
 * alert can watch (W4-5); neither line carries a phone.
 */
final class LoginCodeCeiling
{
    private const DAY_SECONDS = 86400;

    private const TIME_ZONE = 'Asia/Tashkent';

    public function __construct(private readonly RateLimiter $limiter) {}

    public function reserve(string $phone): void
    {
        $holdsAccount = User::query()
            ->where('phone', $phone)
            ->where('status', UserStatus::Active)
            ->exists();

        if ($holdsAccount) {
            return;
        }

        $limit = (int) config('login_codes.daily_limit');
        $count = $this->limiter->hit('login-code:day:'.now(self::TIME_ZONE)->format('Y-m-d'), self::DAY_SECONDS);

        if ($count > $limit) {
            throw ApiException::unavailable('provider_unavailable');
        }

        if ($count === $limit) {
            Log::warning('Login code daily ceiling reached.', ['limit' => $limit]);
        } elseif ($count === intdiv($limit, 2) && $count > 0) {
            Log::warning('Login code daily ceiling half used.', ['limit' => $limit]);
        }
    }
}
