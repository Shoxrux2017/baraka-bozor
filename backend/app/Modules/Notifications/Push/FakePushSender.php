<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Push;

/**
 * Records what would be pushed, in this process only. It never logs or writes
 * anything: a token, a title or a body must not reach a log.
 */
final class FakePushSender implements PushSender
{
    /** @var list<array{token: string, message: PushMessage}> */
    private array $sent = [];

    /** @var list<PushSendResult> */
    private array $answers = [];

    public function send(string $pushToken, PushMessage $message): PushSendResult
    {
        $this->sent[] = ['token' => $pushToken, 'message' => $message];

        return array_shift($this->answers) ?? PushSendResult::sent();
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
     * succeeds.
     */
    public function answerNext(PushSendResult ...$results): void
    {
        $this->answers = [...$this->answers, ...array_values($results)];
    }
}
