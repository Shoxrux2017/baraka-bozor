<?php

declare(strict_types=1);

namespace Tests\Feature\Http;

use App\Models\BusinessSettings;
use App\Models\Enums\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Testing\TestResponse;
use Symfony\Component\HttpFoundation\Response;
use Tests\Support\ImageBytes;
use Tests\TestCase;

/**
 * `400 malformed_request` for input no client should send (`docs/09`
 * section 3, `DL-24`): an unreadable JSON body, and text that is not UTF-8 or
 * holds a NUL byte anywhere in the request.
 */
final class MalformedInputTest extends TestCase
{
    use RefreshDatabase;

    private const LOGIN = '/api/v1/auth/staff/login';

    public function test_an_unreadable_json_body_is_refused_before_the_endpoint_runs(): void
    {
        $token = User::factory()->role(Role::Admin)->create()->createToken('t')->plainTextToken;

        $this->raw('PATCH', '/api/v1/admin/settings/business', '{"markup_percent": "12.5"', $token)
            ->assertStatus(400)
            ->assertJsonPath('code', 'malformed_request')
            ->assertJsonPath('errors', []);

        $this->assertNull(BusinessSettings::current()->updated_by_user_id);
    }

    public function test_the_refusal_carries_a_request_id_on_a_public_endpoint(): void
    {
        $response = $this->raw('POST', self::LOGIN, '{"phone": ', null)
            ->assertStatus(400)
            ->assertJsonPath('code', 'malformed_request');

        $this->assertStringStartsWith('req_', (string) $response->json('request_id'));
    }

    public function test_a_readable_body_and_an_empty_body_are_left_to_the_endpoint(): void
    {
        $this->raw('POST', self::LOGIN, '{"phone": "+998901234567", "password": "Oʻzbek Ёлка ‘’"}', null)
            ->assertStatus(401)
            ->assertJsonPath('code', 'invalid_credentials');

        $this->raw('POST', self::LOGIN, '', null)
            ->assertStatus(422)
            ->assertJsonPath('code', 'validation_failed');
    }

    public function test_a_nul_byte_anywhere_in_a_json_body_is_refused(): void
    {
        foreach ([
            '{"phone": "+998901234567\u0000", "password": "x"}',
            '{"phone": "+998901234567", "pass\u0000word": "x"}',
            '{"phone": "+998901234567", "password": "x", "nested": {"deep": ["a", "b\u0000c"]}}',
        ] as $body) {
            $this->raw('POST', self::LOGIN, $body, null)
                ->assertStatus(400)
                ->assertJsonPath('code', 'malformed_request');
        }
    }

    public function test_a_json_body_that_is_not_utf8_is_refused(): void
    {
        $this->raw('POST', self::LOGIN, "{\"phone\": \"\xFF\", \"password\": \"x\"}", null)
            ->assertStatus(400)
            ->assertJsonPath('code', 'malformed_request');
    }

    public function test_a_nul_byte_or_invalid_utf8_in_the_query_string_is_refused(): void
    {
        $token = User::factory()->customer()->create()->createToken('t')->plainTextToken;

        // A NUL inside a query key never arrives: PHP's own parsing cuts the
        // key there, so `search%00=a` reaches the application as `search=a`.
        foreach (['search=a%00b', 'search=%FF', 'page=1&search[]=%C3', 'search[%FF]=a'] as $query) {
            $this->withToken($token)->getJson('/api/v1/catalog/products?'.$query)
                ->assertStatus(400)
                ->assertJsonPath('code', 'malformed_request');
        }

        $this->withToken($token)->getJson('/api/v1/catalog/products?search='.urlencode('oʻrik ёлка'))->assertOk();
    }

    public function test_a_form_field_or_an_uploaded_file_name_with_a_nul_byte_or_invalid_utf8_is_refused(): void
    {
        $server = ['HTTP_ACCEPT' => 'application/json'];

        $this->call('POST', self::LOGIN, ['phone' => "+998\0", 'password' => 'x'], [], [], $server)
            ->assertStatus(400)
            ->assertJsonPath('code', 'malformed_request');

        foreach (["pomidor\0.png", "pomidor\xFF.png"] as $name) {
            $this->call('POST', self::LOGIN, [], [], ['image' => ImageBytes::png($name)], $server)
                ->assertStatus(400)
                ->assertJsonPath('code', 'malformed_request');
        }
    }

    /**
     * @return TestResponse<Response>
     */
    private function raw(string $method, string $uri, string $body, ?string $token): TestResponse
    {
        $server = ['CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json'];
        if ($token !== null) {
            $server['HTTP_AUTHORIZATION'] = 'Bearer '.$token;
        }

        return $this->call($method, $uri, [], [], [], $server, $body);
    }
}
