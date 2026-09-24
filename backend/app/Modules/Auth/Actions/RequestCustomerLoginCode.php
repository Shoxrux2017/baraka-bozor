<?php

declare(strict_types=1);

namespace App\Modules\Auth\Actions;

use App\Exceptions\ApiException;
use App\Modules\Auth\CodeDelivery\CodeDeliveryFailed;
use App\Modules\Auth\CodeDelivery\CodeDeliveryGateway;
use App\Modules\Auth\LoginCodePolicy;
use App\Modules\Auth\Models\LoginChallenge;
use App\Modules\Auth\TestPhones;
use Illuminate\Cache\RateLimiter;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;

/**
 * `POST /auth/customer/code/request` — docs/09 Section 6.
 *
 * Creates a challenge for the phone and hands the code to the delivery
 * gateway. Nothing in the response, the log or the database says whether an
 * account exists for the phone, and nothing anywhere carries the code except
 * the gateway call and the hash.
 *
 * The counters are incremented before anything else happens and the new count
 * is what decides, so a burst of parallel requests cannot all slip under a
 * limit, and a delivery that fails still costs its slot: retrying a failing
 * provider is bounded like everything else (`DL-11`). Three counters: sixty
 * seconds between sends and five sends per hour per phone, plus ten requests
 * per minute per address so one source cannot pump codes at many phones.
 *
 * A configured test phone gets a challenge for the fixed test code and no
 * delivery at all; the counters apply to it like to any other phone.
 */
final class RequestCustomerLoginCode
{
    public const IP_REQUESTS_PER_MINUTE = 10;

    public function __construct(
        private readonly RateLimiter $limiter,
        private readonly CodeDeliveryGateway $gateway,
        private readonly TestPhones $testPhones,
    ) {}

    public function __invoke(string $phone, string $ip): RequestedLoginCode
    {
        // Broadest first: a request refused on the address alone charges the
        // phone nothing, so one noisy source cannot use up a phone's window.
        $this->reserve("login-code:ip:{$ip}", self::IP_REQUESTS_PER_MINUTE, 60, 'rate_limited');
        $this->reserve("login-code:resend:{$phone}", 1, LoginCodePolicy::RESEND_SECONDS, 'code_resend_too_soon');
        $this->reserve("login-code:hour:{$phone}", LoginCodePolicy::SENDS_PER_HOUR, LoginCodePolicy::HOUR_SECONDS, 'rate_limited');

        $testCode = $this->testPhones->codeFor($phone);
        $code = $testCode ?? self::generate();

        $channel = $testCode !== null ? TestPhones::CHANNEL : $this->deliver($phone, $code);

        DB::transaction(function () use ($phone, $code, $channel): void {
            // The newest challenge is the only live one: a code from an earlier
            // request must stop working once a fresh one has been sent.
            LoginChallenge::query()->openFor($phone)->update(['invalidated_at' => now()]);

            // forceCreate: the model guards every attribute against request
            // input, and these values are all server-generated.
            LoginChallenge::query()->forceCreate([
                'phone' => $phone,
                'purpose' => LoginChallenge::PURPOSE_CUSTOMER_LOGIN,
                'code_hash' => Hash::make($code),
                'failed_attempts' => 0,
                'channel' => $channel,
                'expires_at' => now()->addSeconds(LoginCodePolicy::LIFETIME_SECONDS),
                'created_at' => now(),
            ]);
        });

        return new RequestedLoginCode(
            channel: $channel,
            expiresInSeconds: LoginCodePolicy::LIFETIME_SECONDS,
            resendAvailableInSeconds: LoginCodePolicy::RESEND_SECONDS,
        );
    }

    /**
     * Take one slot under $key, or refuse when that slot is beyond the limit.
     *
     * The increment is atomic in the cache, so concurrent requests see distinct
     * counts and only $max of them pass. A refused request has already been
     * counted under this key and under the keys reserved before it; that keeps
     * a window closed and never widens one.
     */
    private function reserve(string $key, int $max, int $decaySeconds, string $apiCode): void
    {
        if ($this->limiter->hit($key, $decaySeconds) > $max) {
            throw ApiException::tooManyRequests($apiCode, $this->limiter->availableIn($key));
        }
    }

    private function deliver(string $phone, string $code): string
    {
        try {
            return $this->gateway->deliver($phone, $code);
        } catch (CodeDeliveryFailed $failure) {
            // Only a category reaches the log. The provider's own text is not
            // written anywhere: an adapter's transport error can carry the
            // request it was making, and that request carries the code.
            Log::warning('Login code delivery failed.', ['gateway' => $this->gateway::class]);

            throw ApiException::unavailable('provider_unavailable');
        }
    }

    /**
     * Six digits from a cryptographically secure source, leading zeros kept.
     */
    private static function generate(): string
    {
        return str_pad((string) random_int(0, 10 ** LoginCodePolicy::DIGITS - 1), LoginCodePolicy::DIGITS, '0', STR_PAD_LEFT);
    }
}
