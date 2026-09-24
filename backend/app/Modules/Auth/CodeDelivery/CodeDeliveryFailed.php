<?php

declare(strict_types=1);

namespace App\Modules\Auth\CodeDelivery;

use RuntimeException;

/**
 * The provider could not deliver the code.
 *
 * The API answers `503 provider_unavailable`, and the action logs only the
 * gateway class: this message is never written anywhere, so an adapter may
 * put the provider's answer in it for a debugger's eyes, but it must never
 * put the code or the phone in it, and no caller may log it.
 */
final class CodeDeliveryFailed extends RuntimeException {}
