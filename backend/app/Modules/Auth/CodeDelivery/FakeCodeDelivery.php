<?php

declare(strict_types=1);

namespace App\Modules\Auth\CodeDelivery;

/**
 * The development and test gateway. It delivers nothing: it records the code
 * in the in-process sink and reports the `fake` channel, so the client shows
 * a generic "code sent" and a test reads the code back from the sink.
 */
final class FakeCodeDelivery implements CodeDeliveryGateway
{
    public const CHANNEL = 'fake';

    public function __construct(private readonly FakeCodeSink $sink) {}

    public function deliver(string $phone, #[\SensitiveParameter] string $code): string
    {
        $this->sink->record($phone, $code);

        return self::CHANNEL;
    }
}
