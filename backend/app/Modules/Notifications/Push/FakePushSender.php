<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Push;

/**
 * Records what would be pushed, in this process only. It never logs or writes
 * anything: a token, a title or a body must not reach a log. Outside tests it
 * never reports a delivery, because nothing leaves the server.
 */
final class FakePushSender implements PushSender
{
    /** @var list<array{token: string, message: PushMessage}> */
    private array $sent = [];

    /** @var list<PushSendResult> */
    private array $answers = [];

    public function __construct(private readonly bool $reportsDelivery = true) {}

    public function send(string $pushToken, PushMessage $message): PushSendResult
    {
        $this->sent[] = ['token' => $pushToken, 'message' => $message];

        return array_shift($this->answers) ?? ($this->reportsDelivery ? PushSendResult::sent() : PushSendResult::failed('fake_driver'));
    }

    /**
     * @return list<array{token: string, message: PushMessage}>
     */
    public function sent(): array
    {
        return $this->sent;
    }

    /**
     * Queues the answers the next sends get, in order; after them every send
     * succeeds, or fails with `fake_driver` when the fake does not report delivery.
     */
    public function answerNext(PushSendResult ...$results): void
    {
        $this->answers = [...$this->answers, ...array_values($results)];
    }
}
