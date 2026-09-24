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
use Symfony\Component\HttpKernel\Exception\HttpException;

/**
 * `POST /auth/customer/code/request` — docs/09 Section 6.
 *
 * Creates a challenge for the phone and hands the code to the delivery
 * gateway. Nothing in the response, the log or the database says whether an
 * account exists for the phone, and nothing anywhere carries the code except
 * the gateway call and the hash.
 *
 * A configured test phone gets a challenge for the fixed test code and no
 * delivery at all; the counters apply to it like to any other phone.
 */
final class RequestCustomerLoginCode
{
    public function __construct(
        private readonly RateLimiter $limiter,
        private readonly CodeDeliveryGateway $gateway,
        private readonly TestPhones $testPhones,
    ) {}

    public function __invoke(string $phone): RequestedLoginCode
    {
        $resendKey = "login-code:resend:{$phone}";
        $hourKey = "login-code:hour:{$phone}";

        if ($this->limiter->tooManyAttempts($resendKey, 1)) {
            throw ApiException::tooManyRequests('code_resend_too_soon', $this->limiter->availableIn($resendKey));
        }

        if ($this->limiter->tooManyAttempts($hourKey, LoginCodePolicy::SENDS_PER_HOUR)) {
            throw ApiException::rateLimited($this->limiter->availableIn($hourKey));
        }

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

        $this->limiter->hit($resendKey, LoginCodePolicy::RESEND_SECONDS);
        $this->limiter->hit($hourKey, LoginCodePolicy::HOUR_SECONDS);

        return new RequestedLoginCode(
            channel: $channel,
            expiresInSeconds: LoginCodePolicy::LIFETIME_SECONDS,
            resendAvailableInSeconds: LoginCodePolicy::RESEND_SECONDS,
        );
    }

    private function deliver(string $phone, string $code): string
    {
        try {
            return $this->gateway->deliver($phone, $code);
        } catch (CodeDeliveryFailed $failure) {
            // The provider's own text stays in the log; the client gets the
            // stable code and nothing that could name the provider's endpoint.
            Log::warning('Login code delivery failed.', ['reason' => $failure->getMessage()]);

            throw new HttpException(503, 'Login code delivery failed.', $failure);
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
