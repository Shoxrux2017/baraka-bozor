<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Push;

use DateTimeImmutable;
use DateTimeZone;
use Google\Auth\Cache\MemoryCacheItemPool;
use Google\Auth\Credentials\ServiceAccountCredentials;
use Google\Auth\FetchAuthTokenCache;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Psr\Http\Message\RequestInterface;
use Psr\Http\Message\ResponseInterface;

/**
 * Firebase Cloud Messaging (HTTP v1) behind `PushSender` - `docs/07-architecture.md`
 * Section 24, `DL-104`.
 *
 * Google's library signs the service-account JWT and caches the OAuth token
 * for the library's default lifetime; its HTTP calls go through Laravel's
 * `Http` so a test can fake them. The sender is a container singleton, so a
 * worker fetches a token about every 25 minutes, the library's default cache
 * lifetime. A `401` that is not a third-party (APNs) failure drops the cached
 * token and asks for a retry.
 *
 * Answers map onto `PushSendResult`: an unregistered or malformed registration
 * token revokes its device; `429` and `5xx` are retried, honouring
 * `Retry-After`; everything else fails with a code. A code is the FCM error
 * code, else the status Firebase names, when it is upper-case letters and
 * underscores only, otherwise `http_<status>`. Neither the push token, the
 * access token, the key, the title nor the body reaches a log or a code
 * (`AGENTS.md` section 5): the one log line holds a reason only.
 */
final class FcmPushSender implements PushSender
{
    public const SCOPE = 'https://www.googleapis.com/auth/firebase.messaging';

    public const LOG_MESSAGE = 'FCM refused a push.';

    private const SEND_URL = 'https://fcm.googleapis.com/v1/projects/%s/messages:send';

    private const FCM_ERROR_TYPE = 'type.googleapis.com/google.firebase.fcm.v1.FcmError';

    private const BAD_REQUEST_TYPE = 'type.googleapis.com/google.rpc.BadRequest';

    private const DEFAULT_QUOTA_DELAY_SECONDS = 60;

    private readonly FetchAuthTokenCache $tokens;

    private readonly MemoryCacheItemPool $pool;

    public function __construct(private readonly FcmServiceAccount $account)
    {
        $this->pool = new MemoryCacheItemPool;
        $this->tokens = new FetchAuthTokenCache(
            new ServiceAccountCredentials(self::SCOPE, $account->key()),
            null,
            $this->pool,
        );
    }

    public function send(#[\SensitiveParameter] string $pushToken, PushMessage $message): PushSendResult
    {
        try {
            $answer = $this->tokens->fetchAuthToken(self::tokenHandler());
        } catch (ConnectionException|FcmTokenUnavailable) {
            return PushSendResult::retry('auth_unavailable');
        } catch (\Exception) {
            return $this->failed('auth_failed');
        }

        $accessToken = $answer['access_token'] ?? null;

        if (! is_string($accessToken) || $accessToken === '') {
            $oauthError = $answer['error'] ?? null;

            return $this->failed(
                'auth_failed',
                is_string($oauthError) && preg_match('/^[a-z_]{1,64}\z/', $oauthError) === 1
                    ? ['oauth_error' => $oauthError]
                    : [],
            );
        }

        try {
            $android = ['priority' => 'high', 'ttl' => $message->ttlSeconds.'s'];
            $apnsHeaders = ['apns-expiration' => (string) (now()->getTimestamp() + $message->ttlSeconds)];

            if ($message->tag !== null) {
                $android['notification'] = ['tag' => $message->tag];
                $apnsHeaders['apns-collapse-id'] = $message->tag;
            }

            $response = Http::timeout(10)->connectTimeout(5)
                ->withToken($accessToken)
                ->acceptJson()
                ->asJson()
                ->post(sprintf(self::SEND_URL, $this->account->projectId), [
                    'message' => [
                        'token' => $pushToken,
                        'notification' => ['title' => $message->title, 'body' => $message->body],
                        'data' => $message->data,
                        'android' => $android,
                        'apns' => ['headers' => $apnsHeaders],
                    ],
                ]);
        } catch (ConnectionException) {
            return PushSendResult::retry('connection');
        }

        return $response->successful() ? PushSendResult::sent() : $this->refusal($response);
    }

    /**
     * The handler google/auth calls for the token request: it replays the PSR
     * request through Laravel's `Http`, and `429`/`5xx` mean "not now".
     *
     * @return callable(RequestInterface, array<string, mixed>=): ResponseInterface
     */
    private static function tokenHandler(): callable
    {
        return static function (RequestInterface $request, array $options = []): ResponseInterface {
            $headers = [];
            foreach ($request->getHeaders() as $name => $values) {
                if (strcasecmp((string) $name, 'Host') !== 0) {
                    $headers[$name] = implode(', ', $values);
                }
            }

            $response = Http::timeout(10)->connectTimeout(5)
                ->withHeaders($headers)
                ->withBody((string) $request->getBody(), $request->getHeaderLine('Content-Type'))
                ->send($request->getMethod(), (string) $request->getUri());

            if ($response->status() === 429 || $response->status() >= 500) {
                throw new FcmTokenUnavailable('The token endpoint is unavailable.');
            }

            return $response->toPsrResponse();
        };
    }

    private function refusal(Response $response): PushSendResult
    {
        $status = $response->status();
        $body = $response->json();
        $error = is_array($body) && is_array($body['error'] ?? null) ? $body['error'] : [];
        $details = is_array($error['details'] ?? null) ? $error['details'] : [];

        $fcmCode = null;
        $fields = [];
        foreach ($details as $detail) {
            if (! is_array($detail)) {
                continue;
            }

            if (($detail['@type'] ?? null) === self::FCM_ERROR_TYPE) {
                $fcmCode = $detail['errorCode'] ?? null;
            }

            if (($detail['@type'] ?? null) === self::BAD_REQUEST_TYPE && is_array($detail['fieldViolations'] ?? null)) {
                foreach ($detail['fieldViolations'] as $violation) {
                    if (is_array($violation) && is_string($violation['field'] ?? null)) {
                        $fields[] = $violation['field'];
                    }
                }
            }
        }

        $code = self::codeOf($fcmCode) ?? self::codeOf($error['status'] ?? null) ?? 'http_'.$status;

        if ($fcmCode === 'UNREGISTERED') {
            return PushSendResult::rejectedToken('UNREGISTERED');
        }

        if ($code === 'INVALID_ARGUMENT' && $this->isAboutTheToken($fields, $error['message'] ?? null)) {
            return PushSendResult::rejectedToken('invalid_token');
        }

        if ($status === 429 || $status >= 500) {
            return PushSendResult::retry(
                $code,
                self::retryAfterOf($response) ?? ($status === 429 ? self::DEFAULT_QUOTA_DELAY_SECONDS : null),
            );
        }

        if ($status === 401 && $code !== 'THIRD_PARTY_AUTH_ERROR') {
            $this->pool->clear();

            return PushSendResult::retry($code);
        }

        return $this->failed($code);
    }

    /**
     * @param  list<string>  $fields
     */
    private function isAboutTheToken(array $fields, mixed $message): bool
    {
        if ($fields !== []) {
            return $fields === ['message.token'];
        }

        return is_string($message) && stripos($message, 'registration token is not a valid') !== false;
    }

    private static function codeOf(mixed $value): ?string
    {
        return is_string($value) && preg_match('/^[A-Z_]{1,64}\z/', $value) === 1 ? $value : null;
    }

    /**
     * `Retry-After` as delta-seconds or an HTTP-date, read against Laravel's clock.
     */
    private static function retryAfterOf(Response $response): ?int
    {
        $header = trim($response->header('Retry-After'));

        if (preg_match('/^\d{1,9}\z/', $header) === 1) {
            return (int) $header;
        }

        $date = DateTimeImmutable::createFromFormat('D, d M Y H:i:s \G\M\T', $header, new DateTimeZone('UTC'));

        return $date === false ? null : max(0, $date->getTimestamp() - now()->getTimestamp());
    }

    /**
     * @param  array<string, string>  $context
     */
    private function failed(string $code, array $context = []): PushSendResult
    {
        Log::warning(self::LOG_MESSAGE, ['reason' => $code, ...$context]);

        return PushSendResult::failed($code);
    }
}
