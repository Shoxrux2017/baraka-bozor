<?php

declare(strict_types=1);

namespace App\Modules\Auth\CodeDelivery;

use App\Modules\Auth\LoginCodePolicy;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\RequestException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * Telegram Gateway behind `CodeDeliveryGateway` — `docs/07-architecture.md`
 * Section 23, `DL-104`.
 *
 * A code goes out as two calls: `checkSendAbility` says whether Telegram can
 * reach the number and returns a `request_id`; `sendVerificationMessage`
 * delivers our own code under that id. Telegram bills the check, and the send
 * is free when it follows a check, so the two calls stay back to back and
 * neither is ever retried: a retry would pay for a second check. A number
 * Telegram cannot reach is `CodeUndeliverable`; every other failure is
 * `CodeDeliveryFailed`.
 *
 * The token travels only in the `Authorization` header. A transport error
 * carries the request, and the request carries the code and the phone, so
 * both exceptions are thrown bare, without a previous exception, and the one
 * log line holds a reason: the provider's error string when it is upper-case
 * letters and underscores only (so a code can never ride in it), otherwise
 * `connection`, `http_<status>` or `unreadable` (`AGENTS.md` section 5,
 * `DL-11`).
 */
final class TelegramGatewayCodeDelivery implements CodeDeliveryGateway
{
    public const CHANNEL = 'telegram';

    public const BASE_URL = 'https://gatewayapi.telegram.org';

    /** The answers that mean the number has no Telegram to reach. */
    public const UNREACHABLE = ['PHONE_NUMBER_INVALID', 'PHONE_NUMBER_NOT_FOUND', 'PHONE_NUMBER_NOT_AVAILABLE'];

    public function __construct(
        #[\SensitiveParameter]
        private readonly string $token,
    ) {}

    public function deliver(string $phone, #[\SensitiveParameter] string $code): string
    {
        $requestId = $this->requestIdOf($this->call('checkSendAbility', ['phone_number' => $phone]));

        $this->requestIdOf($this->call('sendVerificationMessage', [
            'phone_number' => $phone,
            'request_id' => $requestId,
            'code' => $code,
            'ttl' => LoginCodePolicy::LIFETIME_SECONDS,
        ]));

        return self::CHANNEL;
    }

    /**
     * @param  array<string, mixed>  $payload
     * @return array<string, mixed>
     */
    private function call(string $method, #[\SensitiveParameter] array $payload): array
    {
        try {
            $response = Http::timeout(5)->connectTimeout(3)
                ->withToken($this->token)
                ->acceptJson()
                ->asJson()
                ->post(self::BASE_URL.'/'.$method, $payload);
        } catch (ConnectionException|RequestException) {
            $this->fail('connection');
        }

        // The body is read whatever the HTTP status: the provider explains a
        // refusal in it, and its unreachable-number answer came with a 200 at
        // W4-4's verification (`DL-111`).
        $body = $response->json();

        if (is_array($body) && ($body['ok'] ?? null) === false) {
            $error = $body['error'] ?? null;

            if (is_string($error) && in_array($error, self::UNREACHABLE, true)) {
                throw new CodeUndeliverable('No channel reaches this number.');
            }

            $this->fail(is_string($error) && preg_match('/^[A-Z_]{1,64}\z/', $error) === 1 ? $error : 'unreadable');
        }

        if (! is_array($body) || ($body['ok'] ?? null) !== true) {
            $this->fail($response->successful() ? 'unreadable' : 'http_'.$response->status());
        }

        return $body;
    }

    /**
     * @param  array<string, mixed>  $body
     */
    private function requestIdOf(array $body): string
    {
        $result = $body['result'] ?? null;
        $requestId = is_array($result) ? ($result['request_id'] ?? null) : null;

        if (! is_string($requestId) || $requestId === '') {
            $this->fail('unreadable');
        }

        return $requestId;
    }

    private function fail(string $reason): never
    {
        Log::warning('Telegram Gateway refused a login code.', ['reason' => $reason]);

        throw new CodeDeliveryFailed('Telegram Gateway: '.$reason);
    }
}
