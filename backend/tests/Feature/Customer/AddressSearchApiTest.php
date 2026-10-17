<?php

declare(strict_types=1);

namespace Tests\Feature\Customer;

use App\Models\BusinessSettings;
use App\Models\Enums\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Http\Client\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Log;
use Illuminate\Testing\TestResponse;
use PHPUnit\Framework\Attributes\DataProvider;
use Tests\TestCase;

/**
 * Looking up an address typed in words (`docs/09` section 13, `DL-86` item 1).
 * Google is always a fake here; the key is the literal below.
 */
final class AddressSearchApiTest extends TestCase
{
    use RefreshDatabase;

    private const URL = '/api/v1/customer/address-search';

    private const GOOGLE = 'maps.googleapis.com/maps/api/geocode/json*';

    private const KEY = 'test-geocoding-key';

    private const CENTRE_LAT = '41.311081';

    private const CENTRE_LNG = '69.240562';

    private User $customer;

    protected function setUp(): void
    {
        parent::setUp();

        $this->customer = User::factory()->customer()->create();
        $this->configureArea();
        config(['services.google_maps.geocoding_key' => self::KEY]);
    }

    public function test_a_found_address_answers_its_point(): void
    {
        Http::fake([self::GOOGLE => Http::response($this->found(['street_address']))]);

        $this->search('Navoiy 5')
            ->assertOk()
            ->assertExactJson(['data' => ['latitude' => '41.299512', 'longitude' => '69.240146']]);

        Http::assertSent(function (Request $request): bool {
            parse_str((string) parse_url($request->url(), PHP_URL_QUERY), $query);

            return $query['address'] === 'Navoiy 5'
                && $query['components'] === 'country:UZ'
                && $query['region'] === 'uz'
                && $query['key'] === self::KEY
                && $query['bounds'] === '41.266165,69.180765|41.355997,69.300359';
        });
    }

    public function test_nothing_found_answers_null(): void
    {
        Http::fake([self::GOOGLE => Http::response(['status' => 'ZERO_RESULTS', 'results' => []])]);

        $this->search('Navoiy 5')->assertOk()->assertExactJson(['data' => null]);
    }

    /**
     * @return array<string, array{0: list<string>}>
     */
    public static function wholeAreaTypes(): array
    {
        return [
            'city' => [['locality', 'political']],
            'country' => [['country', 'political']],
            'region' => [['administrative_area_level_1', 'political']],
            'district' => [['administrative_area_level_2', 'political']],
        ];
    }

    /**
     * @param  list<string>  $types
     */
    #[DataProvider('wholeAreaTypes')]
    public function test_a_match_of_the_whole_city_is_nothing_found(array $types): void
    {
        Http::fake([self::GOOGLE => Http::response($this->found($types))]);

        $this->search('Toshkent')->assertOk()->assertExactJson(['data' => null]);
    }

    /**
     * @return array<string, array{0: string}>
     */
    public static function providerFailures(): array
    {
        return [
            'request denied' => ['request_denied'],
            'over query limit' => ['over_query_limit'],
            'over daily limit' => ['over_daily_limit'],
            'http 500' => ['http_500'],
            'connection failure' => ['connection_failure'],
        ];
    }

    #[DataProvider('providerFailures')]
    public function test_a_provider_failure_is_unavailable_and_reveals_nothing(string $failure): void
    {
        Http::fake([self::GOOGLE => match ($failure) {
            'request_denied' => Http::response(['status' => 'REQUEST_DENIED', 'error_message' => 'Bad key test-geocoding-key']),
            'over_query_limit' => Http::response(['status' => 'OVER_QUERY_LIMIT']),
            'over_daily_limit' => Http::response(['status' => 'OVER_DAILY_LIMIT']),
            'http_500' => Http::response('upstream broke on Navoiy', 500),
            default => static function (): never {
                throw new ConnectionException('cURL error 28 for https://maps.googleapis.com/maps/api/geocode/json?address=Navoiy&key=test-geocoding-key');
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

        $response = $this->search('Navoiy 5')->assertStatus(503)->assertJsonPath('code', 'provider_unavailable');

        $this->assertStringNotContainsString(self::KEY, (string) $response->getContent());
        $this->assertStringNotContainsString('Navoiy', (string) $response->getContent());
        $this->assertNotEmpty($logged);
        $this->assertStringNotContainsString(self::KEY, (string) json_encode($logged));
        $this->assertStringNotContainsString('Navoiy', (string) json_encode($logged));
    }

    public function test_without_a_key_the_search_is_unavailable(): void
    {
        config(['services.google_maps.geocoding_key' => null]);
        Http::fake();

        $this->search('Navoiy 5')->assertStatus(503)->assertJsonPath('code', 'provider_unavailable');

        Http::assertNothingSent();
    }

    public function test_without_a_service_area_the_search_is_not_bounded(): void
    {
        $this->configureArea(radius: null);
        Http::fake([self::GOOGLE => Http::response($this->found(['street_address']))]);

        $this->search('Navoiy 5')->assertOk()->assertJsonPath('data.latitude', '41.299512');

        Http::assertSent(function (Request $request): bool {
            parse_str((string) parse_url($request->url(), PHP_URL_QUERY), $query);

            return ! array_key_exists('bounds', $query);
        });
    }

    public function test_the_query_is_validated(): void
    {
        Http::fake();

        foreach ([[], ['query' => 'ab'], ['query' => str_repeat('a', 201)], ['query' => 12345], ['query' => 'Navoiy 5', 'extra' => 1]] as $body) {
            $this->asCustomer()->postJson(self::URL, $body)
                ->assertStatus(422)
                ->assertJsonPath('code', 'validation_failed');
        }

        Http::assertNothingSent();
    }

    public function test_only_a_customer_may_search(): void
    {
        Http::fake();

        $this->postJson(self::URL, ['query' => 'Navoiy 5'])->assertStatus(401);

        $shopper = User::factory()->role(Role::Shopper)->create();
        $this->withToken($shopper->createToken('t')->plainTextToken)
            ->postJson(self::URL, ['query' => 'Navoiy 5'])
            ->assertStatus(403);

        Http::assertNothingSent();
    }

    public function test_searches_are_limited_per_customer(): void
    {
        Http::fake([self::GOOGLE => Http::response(['status' => 'ZERO_RESULTS', 'results' => []])]);

        for ($i = 0; $i < 10; $i++) {
            $this->search('Navoiy 5')->assertOk();
        }

        $this->search('Navoiy 5')->assertStatus(429)->assertJsonPath('code', 'rate_limited')->assertHeader('Retry-After');

        $other = User::factory()->customer()->create();
        $this->withToken($other->createToken('t')->plainTextToken)
            ->postJson(self::URL, ['query' => 'Navoiy 5'])
            ->assertOk();

        // The minute window reopens; ten more today, then ten more: thirty.
        $this->travel(61)->seconds();
        for ($i = 0; $i < 10; $i++) {
            $this->search('Navoiy 5')->assertOk();
        }
        $this->travel(61)->seconds();
        for ($i = 0; $i < 10; $i++) {
            $this->search('Navoiy 5')->assertOk();
        }

        // The minute window is open again, but the thirty-first of the day is not.
        $this->travel(61)->seconds();
        $this->search('Navoiy 5')->assertStatus(429)->assertJsonPath('code', 'rate_limited')->assertHeader('Retry-After');
    }

    /**
     * @param  list<string>  $types
     * @return array<string, mixed>
     */
    private function found(array $types): array
    {
        return [
            'status' => 'OK',
            'results' => [[
                'types' => $types,
                'formatted_address' => 'Navoiy ko\'chasi 5, Toshkent',
                'geometry' => ['location' => ['lat' => 41.2995123, 'lng' => 69.2401456]],
            ]],
        ];
    }

    private function search(string $query): TestResponse
    {
        return $this->asCustomer()->postJson(self::URL, ['query' => $query]);
    }

    private function configureArea(?string $radius = '5.00'): void
    {
        DB::table('business_settings')->where('id', BusinessSettings::SINGLETON_ID)->update([
            'service_centre_latitude' => self::CENTRE_LAT,
            'service_centre_longitude' => self::CENTRE_LNG,
            'service_radius_km' => $radius,
        ]);
    }

    private function asCustomer(): self
    {
        return $this->withToken($this->customer->createToken('t')->plainTextToken);
    }
}
