<?php

declare(strict_types=1);

namespace App\Modules\Notifications\Push;

use RuntimeException;

/**
 * Google's token endpoint answered `429` or `5xx`: the OAuth token could not be
 * had right now, so the push is worth another try. Internal to the FCM sender.
 */
final class FcmTokenUnavailable extends RuntimeException {}
