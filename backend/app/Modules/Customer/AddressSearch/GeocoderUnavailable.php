<?php

declare(strict_types=1);

namespace App\Modules\Customer\AddressSearch;

use RuntimeException;

/**
 * The lookup cannot answer. It carries no text of the provider: a transport
 * message holds the request URL, and the URL holds the key.
 */
final class GeocoderUnavailable extends RuntimeException {}
