<?php

declare(strict_types=1);

namespace App\Modules\Auth\CodeDelivery;

/**
 * Carries a login code to a phone number — `docs/07-architecture.md`
 * Section 23.
 *
 * Implementations: Telegram Gateway (Wave 4), SMS through Eskiz (Wave 5), and
 * the development fake. None of them may log the code, return it through any
 * API, or put it in a header, in any environment.
 */
interface CodeDeliveryGateway
{
    /**
     * Deliver the code and report the channel that carried it:
     * `telegram`, `sms` or `fake`.
     *
     * @throws CodeDeliveryFailed when the provider could not be reached or refused
     */
    public function deliver(string $phone, #[\SensitiveParameter] string $code): string;
}
