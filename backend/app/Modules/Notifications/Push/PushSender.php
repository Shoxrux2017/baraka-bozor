<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Push;

/**
 * Sends one push to one device token. The real adapter (FCM) arrives with
 * W4-8; until then only the fake exists.
 */
interface PushSender
{
    public function send(string $pushToken, PushMessage $message): PushSendResult;
}
