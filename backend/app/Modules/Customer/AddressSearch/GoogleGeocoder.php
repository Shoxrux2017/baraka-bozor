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

    /** What names a point that has no street, nearest first. */
    private const AREA_NAMES = ['neighborhood', 'sublocality_level_2', 'sublocality_level_1', 'sublocality', 'administrative_area_level_2', 'locality'];

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

    public function describe(string $latitude, string $longitude, string $language): ?PointAddress
    {
        $parameters = [
            'latlng' => "{$latitude},{$longitude}",
            'language' => $language,
            'key' => $this->key,
        ];

        try {
            $response = Http::timeout(5)->connectTimeout(3)->acceptJson()->get(self::ENDPOINT, $parameters);
        } catch (ConnectionException|RequestException) {
            $this->fail('connection', 'reverse');
        }

        if (! $response->successful()) {
            $this->fail('http_'.$response->status(), 'reverse');
        }

        $body = $response->json();
        $status = is_array($body) ? ($body['status'] ?? null) : null;

        if ($status === 'ZERO_RESULTS') {
            return null;
        }

        if ($status !== 'OK' || ! is_array($body['results'] ?? null)) {
            $this->fail(is_string($status) ? $status : 'unreadable', 'reverse');
        }

        foreach ($body['results'] as $result) {
            if (! is_array($result) || ! is_array($result['types'] ?? null)) {
                $this->fail('unreadable', 'reverse');
            }

            if ($result['types'] === ['plus_code']) {
                continue;
            }

            return $this->addressOf($result['address_components'] ?? null);
        }

        return null;
    }

    /**
     * The line the first usable result's components make: street and number,
     * else the nearest named area. The formatted address is never read.
     */
    private function addressOf(mixed $components): ?PointAddress
    {
        if (! is_array($components)) {
            $this->fail('unreadable', 'reverse');
        }

        /** @var array<string, string> $named */
        $named = [];
        foreach ($components as $component) {
            if (! is_array($component) || ! is_array($component['types'] ?? null) || ! is_string($component['long_name'] ?? null)) {
                continue;
            }

            foreach ($component['types'] as $type) {
                if (is_string($type)) {
                    $named[$type] ??= $component['long_name'];
                }
            }
        }

        $route = $named['route'] ?? null;
        $house = $named['street_number'] ?? $named['premise'] ?? null;

        if ($route !== null && $house !== null) {
            return new PointAddress("{$route}, {$house}", true);
        }

        if ($house !== null) {
            return new PointAddress($house, true);
        }

        if ($route !== null) {
            return new PointAddress($route, false);
        }

        foreach (self::AREA_NAMES as $type) {
            if (isset($named[$type])) {
                return new PointAddress($named[$type], false);
            }
        }

        return null;
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

    private function fail(string $reason, string $lookup = 'search'): never
    {
        // Only the reason: Google's status or the HTTP status, never the key,
        // the query, the point or the answer.
        Log::warning('address_search.provider_failed', ['reason' => $reason, 'lookup' => $lookup]);

        throw new GeocoderUnavailable;
    }
}
