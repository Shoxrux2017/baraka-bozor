<?php

declare(strict_types=1);

namespace App\Modules\Customer\AddressSearch;

use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\RequestException;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;

/**
 * The Google Geocoding API behind `AddressGeocoder`. The key and the typed
 * query never reach a log or an exception message: a transport error carries
 * the request URL, so it is caught and replaced by a bare `GeocoderUnavailable`.
 * The formatted address in the answer is never read.
 */
final class GoogleGeocoder implements AddressGeocoder
{
    private const ENDPOINT = 'https://maps.googleapis.com/maps/api/geocode/json';

    /** A match of only these kinds says nothing about the house. */
    private const AREA_TYPES = ['locality', 'country', 'administrative_area_level_1', 'administrative_area_level_2', 'political'];

    public function __construct(
        #[\SensitiveParameter]
        private readonly string $key,
    ) {}

    public function locate(#[\SensitiveParameter] string $query, ?SearchBounds $bounds): ?LocatedPoint
    {
        $parameters = [
            'address' => $query,
            'components' => 'country:UZ',
            'region' => 'uz',
            'key' => $this->key,
        ];

        if ($bounds !== null) {
            $parameters['bounds'] = sprintf(
                '%s,%s|%s,%s',
                number_format($bounds->south, 6, '.', ''),
                number_format($bounds->west, 6, '.', ''),
                number_format($bounds->north, 6, '.', ''),
                number_format($bounds->east, 6, '.', ''),
            );
        }

        try {
            $response = Http::timeout(5)->connectTimeout(3)->acceptJson()->get(self::ENDPOINT, $parameters);
        } catch (ConnectionException|RequestException) {
            $this->fail('connection');
        }

        if (! $response->successful()) {
            $this->fail('http_'.$response->status());
        }

        $body = $response->json();
        $status = is_array($body) ? ($body['status'] ?? null) : null;

        if ($status === 'ZERO_RESULTS') {
            return null;
        }

        if ($status !== 'OK') {
            $this->fail(is_string($status) ? $status : 'unreadable');
        }

        return $this->pointOf($body['results'][0] ?? null);
    }

    private function pointOf(mixed $result): ?LocatedPoint
    {
        if (! is_array($result)) {
            $this->fail('unreadable');
        }

        $location = $result['geometry']['location'] ?? null;
        $types = $result['types'] ?? [];

        if (! is_array($location) || ! is_numeric($location['lat'] ?? null) || ! is_numeric($location['lng'] ?? null) || ! is_array($types)) {
            $this->fail('unreadable');
        }

        if ($types !== [] && array_diff($types, self::AREA_TYPES) === []) {
            return null;
        }

        return new LocatedPoint((float) $location['lat'], (float) $location['lng']);
    }

    private function fail(string $reason): never
    {
        // Only the reason: Google's status or the HTTP status, never the key,
        // the query or the answer.
        Log::warning('address_search.provider_failed', ['reason' => $reason]);

        throw new GeocoderUnavailable;
    }
}
