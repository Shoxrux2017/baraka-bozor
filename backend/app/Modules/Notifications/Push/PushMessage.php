<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Push;

use App\Modules\Notifications\NotificationService;

/**
 * A rendered push. `$data` carries only the event and the order id, both
 * strings. `$ttlSeconds` is how long the provider may hold it for an
 * offline device.
 */
final readonly class PushMessage
{
    /**
     * @param  array<string, string>  $data
     */
    public function __construct(
        public string $title,
        public string $body,
        public array $data,
        public int $ttlSeconds = NotificationService::MAX_AGE_SECONDS,
    ) {}
}
