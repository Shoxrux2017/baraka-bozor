<?php

declare(strict_types=1);

namespace Tests\Feature\Notifications;

use App\Modules\Notifications\Push\FcmPushSender;
use App\Modules\Notifications\Push\FcmServiceAccount;
use App\Modules\Notifications\Push\PushMessage;
use App\Modules\Notifications\Push\PushSendResult;
use Firebase\JWT\JWT;
use Firebase\JWT\Key;
use Illuminate\Http\Client\Factory;
use Illuminate\Http\Client\Request;
use Illuminate\Log\Events\MessageLogged;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Http;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\Support\FcmTestKey;
use Tests\TestCase;

/**
 * The FCM HTTP v1 adapter: the service-account token, the message it sends and
 * how each answer maps onto a `PushSendResult`. No test reaches a network.
 */
final class FcmPushSenderTest extends TestCase
{
    private const TOKEN_URL = 'https://oauth2.googleapis.com/token';

    private const SEND_URL = 'https://fcm.googleapis.com/v1/projects/bb-test/messages:send';

    private const ACCESS = 'ya29.test-access';

    private string $pushToken;

    /** @var list<array{level: string, message: string, context: array<string, mixed>}> */
    private array $logs = [];

    protected function setUp(): void
    {
        parent::setUp();

        $this->pushToken = 'fcm-token-'.str_repeat('q', 140);
        $this->travelTo(now()->startOfSecond());
        Http::preventStrayRequests();

        Event::listen(MessageLogged::class, function (MessageLogged $event): void {
            $this->logs[] = ['level' => $event->level, 'message' => $event->message, 'context' => $event->context];
        });
    }

    public function test_a_push_is_sent_with_a_service_account_token(): void
    {
        $this->fakeHttp(Http::response(['name' => 'projects/bb-test/messages/1']));

        $result = $this->sender()->send($this->pushToken, $this->message());

        $this->assertTrue($result->sent);
        Http::assertSentCount(2);

        $recorded = Http::recorded();
        /** @var Request $tokenRequest */
        $tokenRequest = $recorded[0][0];
        /** @var Request $sendRequest */
        $sendRequest = $recorded[1][0];

        $this->assertSame(self::TOKEN_URL, $tokenRequest->url());
        parse_str($tokenRequest->body(), $form);
        $this->assertSame('urn:ietf:params:oauth:grant-type:jwt-bearer', $form['grant_type']);
        $claims = (array) JWT::decode((string) $form['assertion'], new Key(FcmTestKey::publicKey(), 'RS256'));
        $this->assertSame(FcmTestKey::CLIENT_EMAIL, $claims['iss']);
        $this->assertSame(FcmPushSender::SCOPE, $claims['scope']);
        $this->assertSame(FcmTestKey::TOKEN_URI, $claims['aud']);

        $this->assertSame(self::SEND_URL, $sendRequest->url());
        $this->assertSame('Bearer '.self::ACCESS, $sendRequest->header('Authorization')[0]);
        $this->assertSame([
            'message' => [
                'token' => $this->pushToken,
                'notification' => ['title' => 'T', 'body' => 'B'],
                'data' => ['event' => 'order_accepted', 'order_id' => 'o-1'],
                'android' => ['priority' => 'high', 'ttl' => '3600s'],
                'apns' => ['headers' => ['apns-expiration' => (string) (now()->getTimestamp() + 3600)]],
            ],
        ], $sendRequest->data());
    }

    public function test_a_tag_reaches_android_and_apns(): void
    {
        $this->fakeHttp(Http::response(['name' => 'x']));

        $this->assertTrue($this->sender()->send(
            $this->pushToken,
            new PushMessage('T', 'B', ['event' => 'order_accepted', 'order_id' => 'o-1'], tag: 'delivery-1'),
        )->sent);

        /** @var Request $sendRequest */
        $sendRequest = Http::recorded()[1][0];
        $this->assertSame([
            'token' => $this->pushToken,
            'notification' => ['title' => 'T', 'body' => 'B'],
            'data' => ['event' => 'order_accepted', 'order_id' => 'o-1'],
            'android' => ['priority' => 'high', 'ttl' => '3600s', 'notification' => ['tag' => 'delivery-1']],
            'apns' => ['headers' => [
                'apns-expiration' => (string) (now()->getTimestamp() + 3600),
                'apns-collapse-id' => 'delivery-1',
            ]],
        ], $sendRequest->data()['message']);
    }

    public function test_a_message_without_a_tag_sends_neither(): void
    {
        $this->fakeHttp(Http::response(['name' => 'x']));

        $this->assertTrue($this->sender()->send($this->pushToken, $this->message())->sent);

        /** @var Request $sendRequest */
        $sendRequest = Http::recorded()[1][0];
        $message = $sendRequest->data()['message'];
        $this->assertArrayNotHasKey('notification', $message['android']);
        $this->assertArrayNotHasKey('apns-collapse-id', $message['apns']['headers']);
    }

    public function test_the_token_is_fetched_once_for_two_pushes(): void
    {
        $this->fakeHttp(Http::response(['name' => 'x']));
        $sender = $this->sender();

        $this->assertTrue($sender->send($this->pushToken, $this->message())->sent);
        $this->assertTrue($sender->send($this->pushToken, $this->message())->sent);

        Http::assertSentCount(3);
    }

    public function test_an_unregistered_token_revokes_its_device(): void
    {
        $this->fakeHttp(Http::response($this->error(404, 'NOT_FOUND', 'Requested entity was not found.', [
            $this->fcmError('UNREGISTERED'),
        ]), 404));

        $result = $this->sender()->send($this->pushToken, $this->message());

        $this->assertTrue($result->revokesDevice);
        $this->assertFalse($result->retryable);
        $this->assertSame('UNREGISTERED', $result->errorCode);
        $this->assertSame([], $this->warnings());
    }

    public function test_firebases_invalid_token_answer_revokes_the_device(): void
    {
        $this->fakeHttp(Http::response($this->error(
            400,
            'INVALID_ARGUMENT',
            'The registration token is not a valid FCM registration token',
            [$this->fcmError('INVALID_ARGUMENT')],
        ), 400));

        $result = $this->sender()->send($this->pushToken, $this->message());

        $this->assertTrue($result->revokesDevice);
        $this->assertSame('invalid_token', $result->errorCode);
        $this->assertSame([], $this->warnings());
    }

    public function test_a_field_violation_on_the_token_alone_revokes_the_device(): void
    {
        $this->fakeHttp(Http::response($this->error(400, 'INVALID_ARGUMENT', 'Request contains an invalid argument.', [
            $this->badRequest(['message.token']),
        ]), 400));

        $result = $this->sender()->send($this->pushToken, $this->message());

        $this->assertTrue($result->revokesDevice);
        $this->assertSame('invalid_token', $result->errorCode);
    }

    /**
     * @return array<string, array{0: array<string, mixed>}>
     */
    public static function invalidMessages(): array
    {
        $body = static fn (string $message, array $details): array => ['error' => [
            'code' => 400,
            'message' => $message,
            'status' => 'INVALID_ARGUMENT',
            'details' => $details,
        ]];
        $violations = static fn (array $fields): array => [[
            '@type' => 'type.googleapis.com/google.rpc.BadRequest',
            'fieldViolations' => array_map(
                static fn (string $field): array => ['field' => $field, 'description' => 'invalid'],
                $fields,
            ),
        ]];

        return [
            'data value violation' => [$body('Request contains an invalid argument.', $violations(['message.data[0].value']))],
            'token and ttl violations' => [$body('Request contains an invalid argument.', $violations(['message.token', 'message.android.ttl']))],
            'no details' => [$body('Request contains an invalid argument.', [])],
            'too big' => [$body('Android message is too big', [[
                '@type' => 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
                'errorCode' => 'INVALID_ARGUMENT',
            ]])],
        ];
    }

    /**
     * @param  array<string, mixed>  $body
     */
    #[DataProvider('invalidMessages')]
    public function test_an_invalid_message_revokes_nothing(array $body): void
    {
        $this->fakeHttp(Http::response($body, 400));

        $result = $this->sender()->send($this->pushToken, $this->message());

        $this->assertFalse($result->sent);
        $this->assertFalse($result->retryable);
        $this->assertFalse($result->revokesDevice);
        $this->assertSame('INVALID_ARGUMENT', $result->errorCode);
        $this->assertSame([['reason' => 'INVALID_ARGUMENT']], $this->warnings());
    }

    /**
     * @return array<string, array{0: int, 1: mixed, 2: ?string, 3: string, 4: ?int}>
     */
    public static function transient(): array
    {
        $quota = ['error' => ['code' => 429, 'message' => 'Quota exceeded.', 'status' => 'RESOURCE_EXHAUSTED', 'details' => [[
            '@type' => 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
            'errorCode' => 'QUOTA_EXCEEDED',
        ]]]];
        $unavailable = ['error' => ['code' => 503, 'message' => 'Try later.', 'status' => 'UNAVAILABLE']];
        $internal = ['error' => ['code' => 500, 'message' => 'Oops.', 'status' => 'INTERNAL']];

        return [
            'quota without header' => [429, $quota, null, 'QUOTA_EXCEEDED', 60],
            'quota with header' => [429, $quota, '120', 'QUOTA_EXCEEDED', 120],
            'unavailable with header' => [503, $unavailable, '30', 'UNAVAILABLE', 30],
            'internal' => [500, $internal, null, 'INTERNAL', null],
            'html body' => [503, '<html>down</html>', null, 'http_503', null],
            'http-date header' => [503, $unavailable, 'DATE+90', 'UNAVAILABLE', 90],
            'garbage header' => [503, $unavailable, 'soon', 'UNAVAILABLE', null],
        ];
    }

    #[DataProvider('transient')]
    public function test_transient_answers_are_retried(int $status, mixed $body, ?string $retryAfter, string $code, ?int $seconds): void
    {
        if ($retryAfter === 'DATE+90') {
            $retryAfter = now()->addSeconds(90)->toRfc7231String();
        }

        $this->fakeHttp(Http::response($body, $status, $retryAfter === null ? [] : ['Retry-After' => $retryAfter]));

        $result = $this->sender()->send($this->pushToken, $this->message());

        $this->assertTrue($result->retryable);
        $this->assertFalse($result->revokesDevice);
        $this->assertSame($code, $result->errorCode);
        $this->assertSame($seconds, $result->retryAfterSeconds);
    }

    public function test_a_connection_failure_is_retried(): void
    {
        $this->fakeHttp(Http::failedConnection());

        $result = $this->sender()->send($this->pushToken, $this->message());

        $this->assertTrue($result->retryable);
        $this->assertSame('connection', $result->errorCode);
    }

    public function test_a_401_drops_the_cached_token_and_retries(): void
    {
        $this->fakeHttp(Http::sequence()
            ->push($this->error(401, 'UNAUTHENTICATED', 'Request had invalid authentication credentials.'), 401)
            ->push(['name' => 'x']));
        $sender = $this->sender();

        $first = $sender->send($this->pushToken, $this->message());
        $second = $sender->send($this->pushToken, $this->message());

        $this->assertTrue($first->retryable);
        $this->assertSame('UNAUTHENTICATED', $first->errorCode);
        $this->assertTrue($second->sent);
        Http::assertSentCount(4);
        $tokenCalls = collect(Http::recorded())->filter(fn (array $pair): bool => $pair[0]->url() === self::TOKEN_URL);
        $this->assertCount(2, $tokenCalls);
    }

    /**
     * @return array<string, array{0: int, 1: array<string, mixed>, 2: string}>
     */
    public static function refusals(): array
    {
        $fcm = static fn (string $code): array => [[
            '@type' => 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
            'errorCode' => $code,
        ]];

        return [
            'third party auth' => [401, ['error' => ['code' => 401, 'message' => 'm', 'status' => 'UNAUTHENTICATED', 'details' => $fcm('THIRD_PARTY_AUTH_ERROR')]], 'THIRD_PARTY_AUTH_ERROR'],
            'sender mismatch' => [403, ['error' => ['code' => 403, 'message' => 'm', 'status' => 'PERMISSION_DENIED', 'details' => $fcm('SENDER_ID_MISMATCH')]], 'SENDER_ID_MISMATCH'],
            'permission denied' => [403, ['error' => ['code' => 403, 'message' => 'm', 'status' => 'PERMISSION_DENIED']], 'PERMISSION_DENIED'],
            'not found without fcm error' => [404, ['error' => ['code' => 404, 'message' => 'm', 'status' => 'NOT_FOUND']], 'NOT_FOUND'],
        ];
    }

    /**
     * @param  array<string, mixed>  $body
     */
    #[DataProvider('refusals')]
    public function test_other_refusals_fail_without_revoking(int $status, array $body, string $code): void
    {
        $this->fakeHttp(Http::response($body, $status));

        $result = $this->sender()->send($this->pushToken, $this->message());

        $this->assertFalse($result->sent);
        $this->assertFalse($result->retryable);
        $this->assertFalse($result->revokesDevice);
        $this->assertSame($code, $result->errorCode);
        $this->assertSame([['reason' => $code]], $this->warnings());
    }

    public function test_a_token_endpoint_refusal_fails_the_push(): void
    {
        Http::fake([
            self::TOKEN_URL => Http::response(['error' => 'invalid_grant', 'error_description' => 'Invalid JWT Signature.'], 400),
        ]);

        $result = $this->sender()->send($this->pushToken, $this->message());

        $this->assertFalse($result->retryable);
        $this->assertSame('auth_failed', $result->errorCode);
        $this->assertSame([['reason' => 'auth_failed', 'oauth_error' => 'invalid_grant']], $this->warnings());
        Http::assertSentCount(1);
    }

    public function test_a_token_endpoint_error_that_is_not_a_code_is_not_logged(): void
    {
        Http::fake([
            self::TOKEN_URL => Http::response(['error' => 'Not A Code!', 'error_description' => 'Invalid JWT Signature.'], 400),
        ]);

        $result = $this->sender()->send($this->pushToken, $this->message());

        $this->assertSame('auth_failed', $result->errorCode);
        $this->assertSame([['reason' => 'auth_failed']], $this->warnings());
    }

    public function test_an_unavailable_token_endpoint_is_retried(): void
    {
        Http::fake([self::TOKEN_URL => Http::response('down', 503)]);
        $unavailable = $this->sender()->send($this->pushToken, $this->message());

        $this->assertTrue($unavailable->retryable);
        $this->assertSame('auth_unavailable', $unavailable->errorCode);
        Http::assertSentCount(1);
    }

    public function test_an_unreachable_token_endpoint_is_retried(): void
    {
        Http::fake([self::TOKEN_URL => Http::failedConnection()]);
        $unreachable = $this->sender()->send($this->pushToken, $this->message());

        $this->assertTrue($unreachable->retryable);
        $this->assertSame('auth_unavailable', $unreachable->errorCode);
        Http::assertNotSent(fn (Request $request): bool => $request->url() === self::SEND_URL);
    }

    public function test_no_secret_reaches_a_log_or_a_result(): void
    {
        $message = new PushMessage('T-title-text', 'B-body-text', ['event' => 'order_accepted', 'order_id' => 'o-1']);
        $results = [];

        $this->fakeHttp(Http::response(['name' => 'x']));
        $results[] = $this->sender()->send($this->pushToken, $message);
        $this->assertTrue($results[0]->sent);

        $this->freshHttp();
        $this->fakeHttp(Http::response($this->error(400, 'INVALID_ARGUMENT', 'Bad '.$this->pushToken, [
            $this->badRequest(['message.data[0].value']),
        ]), 400));
        $results[] = $this->sender()->send($this->pushToken, $message);
        $this->assertSame('INVALID_ARGUMENT', $results[1]->errorCode);

        $this->freshHttp();
        Http::fake([self::TOKEN_URL => Http::response(['error' => 'invalid_grant', 'error_description' => 'Invalid JWT Signature.'], 400)]);
        $results[] = $this->sender()->send($this->pushToken, $message);
        $this->assertSame('auth_failed', $results[2]->errorCode);

        $this->freshHttp();
        $this->fakeHttp(Http::failedConnection());
        $results[] = $this->sender()->send($this->pushToken, $message);
        $this->assertSame('connection', $results[3]->errorCode);

        $haystack = json_encode([
            array_map(static fn (array $log): array => [$log['message'], $log['context']], $this->logs),
            array_map(static fn (PushSendResult $result): ?string => $result->errorCode, $results),
        ], JSON_THROW_ON_ERROR);

        $needles = [$this->pushToken, self::ACCESS, FcmTestKey::encoded(), 'T-title-text', 'B-body-text'];
        foreach (explode("\n", FcmTestKey::privateKey()) as $line) {
            if (strlen($line) > 10) {
                $needles[] = $line;
            }
        }

        foreach ($needles as $needle) {
            $this->assertStringNotContainsString($needle, $haystack);
        }
    }

    /**
     * A second `Http::fake` for a URL never overrides the first stub, so a test
     * that runs several scenarios starts each one on a fresh factory.
     */
    private function freshHttp(): void
    {
        Http::swap(new Factory);
        Http::preventStrayRequests();
    }

    private function sender(): FcmPushSender
    {
        return new FcmPushSender(FcmServiceAccount::fromConfig(FcmTestKey::encoded()));
    }

    private function message(): PushMessage
    {
        return new PushMessage('T', 'B', ['event' => 'order_accepted', 'order_id' => 'o-1']);
    }

    /**
     * The token endpoint answers a good token; the send endpoint answers `$send`.
     */
    private function fakeHttp(mixed $send): void
    {
        Http::fake([
            self::TOKEN_URL => Http::response(['access_token' => self::ACCESS, 'expires_in' => 3599, 'token_type' => 'Bearer']),
            self::SEND_URL => $send,
        ]);
    }

    /**
     * @param  list<array<string, mixed>>  $details
     * @return array<string, mixed>
     */
    private function error(int $code, string $status, string $message, array $details = []): array
    {
        return ['error' => ['code' => $code, 'message' => $message, 'status' => $status] + ($details === [] ? [] : ['details' => $details])];
    }

    /**
     * @return array<string, string>
     */
    private function fcmError(string $code): array
    {
        return ['@type' => 'type.googleapis.com/google.firebase.fcm.v1.FcmError', 'errorCode' => $code];
    }

    /**
     * @param  list<string>  $fields
     * @return array<string, mixed>
     */
    private function badRequest(array $fields): array
    {
        return [
            '@type' => 'type.googleapis.com/google.rpc.BadRequest',
            'fieldViolations' => array_map(
                static fn (string $field): array => ['field' => $field, 'description' => 'invalid'],
                $fields,
            ),
        ];
    }

    /**
     * @return list<array<string, mixed>>
     */
    private function warnings(): array
    {
        return array_values(array_map(
            static fn (array $log): array => $log['context'],
            array_filter($this->logs, static fn (array $log): bool => $log['level'] === 'warning' && $log['message'] === FcmPushSender::LOG_MESSAGE),
        ));
    }
}
