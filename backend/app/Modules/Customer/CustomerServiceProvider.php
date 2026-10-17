<?php

declare(strict_types=1);

namespace App\Modules\Customer;

use App\Modules\Customer\AddressSearch\AddressGeocoder;
use App\Modules\Customer\AddressSearch\GoogleGeocoder;
use App\Modules\Customer\AddressSearch\UnconfiguredGeocoder;
use Illuminate\Support\ServiceProvider;

/**
 * Wires the Customer module: the address lookup behind its interface.
 *
 * Collected by the module provider registry; nothing lists this class by hand.
 */
final class CustomerServiceProvider extends ServiceProvider
{
    public function register(): void
    {
        // Resolved per use, so the key is read when a lookup runs.
        $this->app->bind(AddressGeocoder::class, static function (): AddressGeocoder {
            $key = config('services.google_maps.geocoding_key');

            return is_string($key) && $key !== ''
                ? new GoogleGeocoder($key)
                : new UnconfiguredGeocoder;
        });
    }
}
