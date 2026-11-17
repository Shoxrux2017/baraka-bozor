<?php

declare(strict_types=1);

namespace Tests\Feature\Customer;

use App\Models\Enums\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

/**
 * Naming the point under the map pin (`docs/09` section 13, `DL-138` item 3).
 * Google is always a fake here; the key is the literal below.
 */
final class AddressReverseApiTest extends TestCase
{
    use RefreshDatabase;

    private const URL = '/api/v1/customer/address-search/reverse';

    private const GOOGLE = 'maps.googleapis.com/maps/api/geocode/json*';

    private const KEY = 'test-geocoding-key';

    private const LAT = '41.311081';

    private const LNG = '69.240562';

    private User $customer;

    protected function setUp(): void
    {
        parent::setUp();

        $this->customer = User::factory()->customer()->create();
        config(['services.google_maps.geocoding_key' => self::KEY]);
    }

    public function test_a_house_answers_its_street_and_number(): void
    {
        Http::fake([self::GOOGLE => Http::response($this->found([
            $this->googleResult(['street_address'], [['route', "Navoiy ko'chasi"], ['street_number', '12']]),
        ]))]);

        $this->reverse()
            ->assertOk()
            ->assertExactJson(['data' => ['line' => "Navoiy ko'chasi, 12", 'house_known' => true]]);

        Http::assertSent(function (Request $request): bool {
            parse_str((string) parse_url($request->url(), PHP_URL_QUERY), $query);

            return $query['latlng'] === '41.311081,69.240562'
                && $query['language'] === 'uz'
                && $query['key'] === self::KEY;
        });
    }

    public function test_a_street_without_a_number_is_not_a_house(): void
    {
        Http::fake([self::GOOGLE => Http::response($this->found([
            $this->googleResult(['route'], [['route', "Navoiy ko'chasi"], ['locality', 'Toshkent']]),
        ]))]);

        $this->reverse()->assertOk()
            ->assertExactJson(['data' => ['line' => "Navoiy ko'chasi", 'house_known' => false]]);
    }

    public function test_a_premise_is_a_house(): void
    {
        Http::fake([self::GOOGLE => Http::response($this->found([
            $this->googleResult(['premise'], [['route', 'Amir Temur'], ['premise', 'Orzu savdo']]),
        ]))]);

        $this->reverse()->assertOk()
            ->assertExactJson(['data' => ['line' => 'Amir Temur, Orzu savdo', 'house_known' => true]]);
    }

    public function test_a_premise_alone_is_a_house(): void
    {
        Http::fake([self::GOOGLE => Http::response($this->found([
            $this->googleResult(['premise'], [['premise', 'Orzu savdo']]),
        ]))]);

        $this->reverse()->assertOk()
            ->assertExactJson(['data' => ['line' => 'Orzu savdo', 'house_known' => true]]);
    }

    public function test_a_district_alone_is_named_without_a_house(): void
    {
        Http::fake([self::GOOGLE => Http::response($this->found([
            $this->googleResult(['administrative_area_level_2'], [['administrative_area_level_2', 'Qibray tumani']]),
        ]))]);

        $this->reverse()->assertOk()
            ->assertExactJson(['data' => ['line' => 'Qibray tumani', 'house_known' => false]]);
    }

    public function test_plus_codes_are_skipped(): void
    {
        Http::fake([self::GOOGLE => Http::response($this->found([
            $this->googleResult(['plus_code'], [['route', 'Wrong']]),
            $this->googleResult(['route'], [['route', "Navoiy ko'chasi"]]),
        ]))]);

        $this->reverse()->assertOk()
            ->assertExactJson(['data' => ['line' => "Navoiy ko'chasi", 'house_known' => false]]);
    }

    public function test_only_plus_codes_answer_null(): void
    {
        Http::fake([self::GOOGLE => Http::response($this->found([
            $this->googleResult(['plus_code'], [['route', 'Wrong']]),
        ]))]);

        $this->reverse()->assertOk()->assertExactJson(['data' => null]);
    }

    public function test_nothing_found_answers_null(): void
    {
        Http::fake([self::GOOGLE => Http::response(['status' => 'ZERO_RESULTS', 'results' => []])]);

        $this->reverse()->assertOk()->assertExactJson(['data' => null]);
    }

    /**
     * @return array<string, array{0: string}>
     */
    public static function providerFailures(): array
    {
        return [
            'connection' => ['connection'],
            'http 500' => ['http_500'],
            'request denied' => ['request_denied'],
            'unreadable' => ['unreadable'],
        ];
    }

    #[DataProvider('providerFailures')]
    public function test_a_provider_failure_is_unavailable_and_reveals_nothing(string $failure): void
    {
        Http::fake([self::GOOGLE => match ($failure) {
            'request_denied' => Http::response(['status' => 'REQUEST_DENIED', 'error_message' => 'Bad key test-geocoding-key at 41.311081,69.240562']),
            'http_500' => Http::response('upstream broke at 41.311081,69.240562', 500),
            'unreadable' => Http::response('<html>not json</html>', 200),
            default => static function (): never {
                throw new ConnectionException('cURL error 28 for https://maps.googleapis.com/maps/api/geocode/json?latlng=41.311081,69.240562&key=test-geocoding-key');
            },
        }]);

        /** @var list<array<int, mixed>> $logged */
        $logged = [];
        $spy = Log::spy();
        foreach (['emergency', 'alert', 'critical', 'error', 'warning', 'notice', 'info', 'debug', 'log'] as $level) {
            $spy->shouldReceive($level)->andReturnUsing(function (...$arguments) use (&$logged): void {
                $logged[] = $arguments;
            });
        }

        $response = $this->reverse()->assertStatus(503)->assertJsonPath('code', 'provider_unavailable');

        $this->assertNotEmpty($logged);
        foreach ($logged as $entry) {
            $this->assertSame('address_search.provider_failed', $entry[0]);
            $this->assertSame(['reason', 'lookup'], array_keys($entry[1]));
            $this->assertSame('reverse', $entry[1]['lookup']);
        }

        foreach ([(string) $response->getContent(), (string) json_encode($logged)] as $text) {
            $this->assertStringNotContainsString(self::KEY, $text);
            $this->assertStringNotContainsString('41.3110', $text);
            $this->assertStringNotContainsString('69.2405', $text);
        }
    }

    public function test_without_a_key_the_lookup_is_unavailable(): void
    {
        config(['services.google_maps.geocoding_key' => null]);
        Http::fake();

        $this->reverse()->assertStatus(503)->assertJsonPath('code', 'provider_unavailable');

        Http::assertNothingSent();
    }

    public function test_the_point_and_language_are_validated(): void
    {
        Http::fake();

        $valid = ['latitude' => self::LAT, 'longitude' => self::LNG, 'language' => 'uz'];
        $bad = [
            ['latitude', ['latitude' => 41.311081] + $valid],
            ['latitude', ['latitude' => '41.1234567'] + $valid],
            ['latitude', ['latitude' => '91'] + $valid],
            ['longitude', ['longitude' => '181'] + $valid],
            ['language', ['language' => 'en'] + $valid],
            ['language', array_diff_key($valid, ['language' => 1])],
            ['longitude', array_diff_key($valid, ['longitude' => 1])],
            ['extra', $valid + ['extra' => 1]],
        ];

        foreach ($bad as [$field, $body]) {
            $this->asCustomer()->postJson(self::URL, $body)
                ->assertStatus(422)
                ->assertJsonPath('code', 'validation_failed');
        }

        Http::assertNothingSent();
    }

    public function test_only_a_customer_may_look_up(): void
    {
        Http::fake();
        $body = ['latitude' => self::LAT, 'longitude' => self::LNG, 'language' => 'uz'];

        $this->postJson(self::URL, $body)->assertStatus(401);

        $shopper = User::factory()->role(Role::Shopper)->create();
        $this->withToken($shopper->createToken('t')->plainTextToken)
            ->postJson(self::URL, $body)
            ->assertStatus(403);

        Http::assertNothingSent();
    }

    public function test_lookups_are_limited_per_customer_apart_from_searches(): void
    {
        Http::fake([self::GOOGLE => Http::response(['status' => 'ZERO_RESULTS', 'results' => []])]);

        for ($i = 0; $i < 10; $i++) {
            $this->reverse()->assertOk();
        }

        $this->reverse()->assertStatus(429)->assertJsonPath('code', 'rate_limited')->assertHeader('Retry-After');

        // The search has its own counters.
        $this->asCustomer()->postJson('/api/v1/customer/address-search', ['query' => 'Navoiy 5'])->assertOk();

        $other = User::factory()->customer()->create();
        $this->withToken($other->createToken('t')->plainTextToken)
            ->postJson(self::URL, ['latitude' => self::LAT, 'longitude' => self::LNG, 'language' => 'ru'])
            ->assertOk();

        $this->travel(61)->seconds();
        for ($i = 0; $i < 10; $i++) {
            $this->reverse()->assertOk();
        }
        $this->travel(61)->seconds();
        for ($i = 0; $i < 10; $i++) {
            $this->reverse()->assertOk();
        }

        // The minute window is open again, but the thirty-first of the day is not.
        $this->travel(61)->seconds();
        $this->reverse()->assertStatus(429)->assertJsonPath('code', 'rate_limited')->assertHeader('Retry-After');
    }

    /**
     * @param  list<string>  $types
     * @param  list<array{0: string, 1: string}>  $components  type and name pairs
     * @return array<string, mixed>
     */
    private function googleResult(array $types, array $components): array
    {
        return [
            'types' => $types,
            'formatted_address' => 'Never read',
            'address_components' => array_map(
                static fn (array $pair): array => ['long_name' => $pair[1], 'short_name' => $pair[1], 'types' => [$pair[0]]],
                $components,
            ),
            'geometry' => ['location' => ['lat' => 41.311081, 'lng' => 69.240562]],
        ];
    }

    /**
     * @param  list<array<string, mixed>>  $results
     * @return array<string, mixed>
     */
    private function found(array $results): array
    {
        return ['status' => 'OK', 'results' => $results];
    }

    private function reverse(string $language = 'uz'): TestResponse
    {
        return $this->asCustomer()->postJson(self::URL, [
            'latitude' => self::LAT,
            'longitude' => self::LNG,
            'language' => $language,
        ]);
    }

    private function asCustomer(): self
    {
        return $this->withToken($this->customer->createToken('t')->plainTextToken);
    }
}
