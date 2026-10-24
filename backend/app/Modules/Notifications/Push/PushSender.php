<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Push;

/**
 * Sends one push to one device token. The real adapter is FCM; the fake
 * stands in for it in tests and local development.
 */
interface PushSender
{
    public function send(string $pushToken, PushMessage $message): PushSendResult;
}
