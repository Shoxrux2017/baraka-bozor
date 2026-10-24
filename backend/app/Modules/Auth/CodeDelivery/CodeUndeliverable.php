<?php

declare(strict_types=1);

namespace App\Modules\Auth\CodeDelivery;

use RuntimeException;

/**
 * No channel the gateway has reaches this number (`DL-104`).
 *
 * Not an outage: the API answers `409 code_delivery_unavailable`, so the
 * client can say so instead of asking the Customer to try again. The message
 * is a fixed sentence and never carries the provider's answer or the phone.
 */
final class CodeUndeliverable extends RuntimeException {}
