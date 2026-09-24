<?php

declare(strict_types=1);

namespace App\Modules\Auth\CodeDelivery;

use RuntimeException;

/**
 * The provider could not deliver the code. The message is for the log only;
 * the API answers `503 provider_unavailable` and never repeats provider text.
 */
final class CodeDeliveryFailed extends RuntimeException {}
