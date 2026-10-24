<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Push;

/**
 * A rendered push. `$data` carries only the event and the order id, both
 * strings.
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
    ) {}
}
