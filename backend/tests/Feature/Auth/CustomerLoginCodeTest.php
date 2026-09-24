<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\Enums\Role;
use App\Models\User;
use App\Modules\Auth\CodeDelivery\CodeDeliveryFailed;
use App\Modules\Auth\CodeDelivery\CodeDeliveryGateway;
use App\Modules\Auth\CodeDelivery\FakeCodeSink;
use App\Modules\Auth\Models\LoginChallenge;
use App\Modules\Auth\TestPhones;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * `POST /api/v1/auth/customer/code/request` and `/verify` — docs/09
 * Sections 6 and 7, docs/04 Section 2, BR-ROLE-003, BR-ROLE-010, BR-ROLE-011.
 */
final class CustomerLoginCodeTest extends TestCase
{
    use RefreshDatabase;

    private const PHONE = '+998901234567';

    private const TEST_PHONE = '+998900000099';

    private const TEST_CODE = '000000';

    public function test_requesting_a_code_reports_the_channel_and_the_timers_and_never_the_code(): void
    {
        $response = $this->request(self::PHONE);

        $response->assertOk()->assertExactJson(['data' => [
            'channel' => 'fake',
            'expires_in_seconds' => 300,
            'resend_available_in_seconds' => 60,
        ]]);

        $code = $this->sink()->codeFor(self::PHONE);
        $this->assertNotNull($code, 'the fake gateway delivered a code');
        $this->assertMatchesRegularExpression('/^[0-9]{6}$/', $code);
        $this->assertStringNotContainsString($code, (string) $response->getContent());

        $challenge = LoginChallenge::query()->openFor(self::PHONE)->sole();
        $this->assertSame('fake', $challenge->channel);
        $this->assertNotSame($code, $challenge->code_hash, 'only a hash of the code is stored');
        $this->assertSame(0, $challenge->failed_attempts);
    }

    public function test_the_response_does_not_disclose_whether_an_account_exists(): void
    {
        User::factory()->customer()->create(['phone' => self::PHONE]);

        $known = $this->request(self::PHONE)->json();
        $unknown = $this->request('+998907777777')->json();

        $this->assertSame($known, $unknown);
    }

    public function test_verifying_the_code_creates_the_customer_and_issues_a_token(): void
    {
        $this->request(self::PHONE)->assertOk();

        $response = $this->verify(self::PHONE, $this->codeFor(self::PHONE));

        $response->assertOk()
            ->assertJsonPath('data.user.role', 'customer')
            ->assertJsonPath('data.user.phone', self::PHONE)
            ->assertJsonPath('data.user.full_name', null)
            ->assertJsonPath('data.user.status', 'active')
            ->assertJsonPath('data.user.must_change_password', false)
            ->assertJsonPath('data.user.preferred_language', 'uz');

        $customer = User::query()->where('phone', self::PHONE)->sole();
        $this->assertSame(Role::Customer, $customer->role);
        $this->assertNull($customer->password);
        $this->assertNotNull($customer->last_login_at);

        $this->withToken((string) $response->json('data.token'))->getJson('/api/v1/auth/me')
            ->assertOk()
            ->assertJsonPath('data.id', $customer->id);

        $this->assertNotNull(LoginChallenge::query()->sole()->consumed_at, 'the challenge is consumed');
    }

    public function test_a_consumed_code_cannot_be_used_twice(): void
    {
        $this->request(self::PHONE);
        $code = $this->codeFor(self::PHONE);

        $this->verify(self::PHONE, $code)->assertOk();
        $this->assertRefused($this->verify(self::PHONE, $code), 'code_invalid');
    }

    public function test_an_existing_active_customer_is_resolved_not_duplicated(): void
    {
        $existing = User::factory()->customer()->create(['phone' => self::PHONE, 'full_name' => 'Nodira']);

        $this->request(self::PHONE);
        $this->verify(self::PHONE, $this->codeFor(self::PHONE))
            ->assertOk()
            ->assertJsonPath('data.user.id', $existing->id)
            ->assertJsonPath('data.user.full_name', 'Nodira');

        $this->assertSame(1, User::query()->where('phone', self::PHONE)->count());
    }

    public function test_a_customer_account_is_created_beside_an_active_staff_account_on_the_phone(): void
    {
        $staff = User::factory()->role(Role::Shopper)->create(['phone' => self::PHONE]);

        $this->request(self::PHONE);
        $response = $this->verify(self::PHONE, $this->codeFor(self::PHONE))->assertOk();

        $this->assertNotSame($staff->id, $response->json('data.user.id'), 'never a staff session');
        $this->assertSame('customer', $response->json('data.user.role'));
        $this->assertSame(2, User::query()->where('phone', self::PHONE)->count());
    }

    public function test_a_wrong_code_is_counted_and_the_sixth_attempt_is_exhausted_even_when_right(): void
    {
        $this->request(self::PHONE);
        $code = $this->codeFor(self::PHONE);
        $wrong = $code === '111111' ? '222222' : '111111';

        for ($attempt = 1; $attempt <= 5; $attempt++) {
            $this->assertRefused($this->verify(self::PHONE, $wrong), 'code_invalid');
        }

        $this->assertSame(5, LoginChallenge::query()->sole()->failed_attempts);
        $this->assertRefused($this->verify(self::PHONE, $code), 'code_attempts_exhausted');
        $this->assertSame(0, User::query()->count(), 'no account was created');
    }

    public function test_an_expired_code_is_refused_as_expired(): void
    {
        $this->request(self::PHONE);
        $code = $this->codeFor(self::PHONE);

        $this->travel(5)->minutes();
        $this->travel(1)->seconds();

        $this->assertRefused($this->verify(self::PHONE, $code), 'code_expired');
    }

    public function test_verifying_without_any_challenge_is_code_invalid(): void
    {
        $this->assertRefused($this->verify(self::PHONE, '123456'), 'code_invalid');
    }

    public function test_a_new_request_invalidates_the_previous_challenge(): void
    {
        $this->request(self::PHONE);
        $first = LoginChallenge::query()->sole();

        $this->travel(61)->seconds();
        $this->request(self::PHONE)->assertOk();

        // The earlier challenge is closed in the database, not merely
        // shadowed by the newer one, so its code cannot be reached by any
        // lookup order.
        $this->assertNotNull($first->fresh()?->invalidated_at);
        $this->assertSame(1, LoginChallenge::query()->openFor(self::PHONE)->count());

        $this->verify(self::PHONE, $this->codeFor(self::PHONE))->assertOk();
    }

    public function test_a_failed_delivery_still_costs_the_send_slot(): void
    {
        $this->app->instance(CodeDeliveryGateway::class, new class implements CodeDeliveryGateway
        {
            public function deliver(string $phone, string $code): string
            {
                throw new CodeDeliveryFailed('down');
            }
        });

        $this->request(self::PHONE)->assertStatus(503);

        // Retrying a failing provider is bounded like any other send.
        $this->request(self::PHONE)->assertStatus(429)->assertJsonPath('code', 'code_resend_too_soon');
    }

    public function test_ten_requests_per_address_per_minute(): void
    {
        for ($attempt = 1; $attempt <= 10; $attempt++) {
            $this->withServerVariables(['REMOTE_ADDR' => '203.0.113.10'])
                ->postJson('/api/v1/auth/customer/code/request', ['phone' => sprintf('+99890%07d', $attempt)])
                ->assertOk();
        }

        $this->withServerVariables(['REMOTE_ADDR' => '203.0.113.10'])
            ->postJson('/api/v1/auth/customer/code/request', ['phone' => '+998901111111'])
            ->assertStatus(429)
            ->assertJsonPath('code', 'rate_limited');

        // The refusal on the address charged that phone nothing: it can still
        // be served from another address at once.
        $this->withServerVariables(['REMOTE_ADDR' => '203.0.113.11'])
            ->postJson('/api/v1/auth/customer/code/request', ['phone' => '+998901111111'])
            ->assertOk();
    }

    public function test_a_resend_inside_sixty_seconds_is_refused(): void
    {
        $this->request(self::PHONE)->assertOk();

        $refused = $this->request(self::PHONE);
        $refused->assertStatus(429)->assertJsonPath('code', 'code_resend_too_soon')->assertHeader('Retry-After');

        $this->assertSame(1, LoginChallenge::query()->count(), 'no second challenge was created');

        $this->travel(61)->seconds();
        $this->request(self::PHONE)->assertOk();
    }

    public function test_five_sends_per_phone_per_hour(): void
    {
        for ($send = 1; $send <= 5; $send++) {
            $this->request(self::PHONE)->assertOk();
            $this->travel(61)->seconds();
        }

        $this->request(self::PHONE)->assertStatus(429)->assertJsonPath('code', 'rate_limited');

        // Another phone is not affected.
        $this->request('+998907777777')->assertOk();
    }

    public function test_a_blocked_customer_is_refused_only_after_the_code_is_valid(): void
    {
        User::factory()->customer()->blocked()->create(['phone' => self::PHONE]);

        $this->request(self::PHONE)->assertOk();
        $code = $this->codeFor(self::PHONE);
        $wrong = $code === '111111' ? '222222' : '111111';

        // A wrong code says nothing about the account.
        $this->assertRefused($this->verify(self::PHONE, $wrong), 'code_invalid');

        // The right code reaches the block, and no fresh account escapes it.
        $this->assertRefused($this->verify(self::PHONE, $code), 'account_blocked');
        $this->assertSame(1, User::query()->where('phone', self::PHONE)->count());
    }

    public function test_a_test_phone_verifies_with_the_fixed_code_and_receives_nothing(): void
    {
        $this->configureTestPhone();

        $this->request(self::TEST_PHONE)->assertOk()->assertJsonPath('data.channel', 'test');

        $this->assertNull($this->sink()->codeFor(self::TEST_PHONE), 'nothing was delivered');
        $this->assertSame('test', LoginChallenge::query()->sole()->channel);

        $this->verify(self::TEST_PHONE, self::TEST_CODE)->assertOk()->assertJsonPath('data.user.phone', self::TEST_PHONE);
    }

    public function test_the_fixed_code_does_not_open_a_phone_that_is_not_a_test_phone(): void
    {
        $this->configureTestPhone();

        $this->request(self::PHONE)->assertOk()->assertJsonPath('data.channel', 'fake');

        $this->assertRefused($this->verify(self::PHONE, self::TEST_CODE), 'code_invalid');
    }

    public function test_a_delivery_failure_is_provider_unavailable_and_stores_nothing(): void
    {
        $this->app->instance(CodeDeliveryGateway::class, new class implements CodeDeliveryGateway
        {
            public function deliver(string $phone, string $code): string
            {
                throw new CodeDeliveryFailed('gateway.example.test answered 500 for merchant m-42');
            }
        });

        $response = $this->request(self::PHONE);

        $response->assertStatus(503)->assertJsonPath('code', 'provider_unavailable');
        $this->assertStringNotContainsString('gateway.example.test', (string) $response->getContent());
        $this->assertStringNotContainsString('m-42', (string) $response->getContent());
        $this->assertSame(0, LoginChallenge::query()->count());
    }

    public function test_a_malformed_phone_or_code_is_a_validation_failure(): void
    {
        $this->request('998901234567')->assertStatus(422)->assertJsonValidationErrors(['phone']);
        $this->verify(self::PHONE, '12345')->assertStatus(422)->assertJsonValidationErrors(['code']);
        $this->verify(self::PHONE, 'abcdef')->assertStatus(422)->assertJsonValidationErrors(['code']);

        $this->postJson('/api/v1/auth/customer/code/request', ['phone' => self::PHONE, 'role' => 'admin'])
            ->assertStatus(422)->assertJsonValidationErrors(['role']);
    }

    /**
     * The provider resolves the test phones at boot, before a test can change
     * the configuration, so the resolved instance is dropped and the singleton
     * reads the new values on its next resolution.
     */
    private function configureTestPhone(): void
    {
        config(['login_codes.test_phones' => [self::TEST_PHONE], 'login_codes.test_code' => self::TEST_CODE]);

        $this->app->forgetInstance(TestPhones::class);
    }

    private function request(string $phone): TestResponse
    {
        return $this->postJson('/api/v1/auth/customer/code/request', ['phone' => $phone]);
    }

    private function verify(string $phone, string $code): TestResponse
    {
        return $this->postJson('/api/v1/auth/customer/code/verify', ['phone' => $phone, 'code' => $code]);
    }

    private function codeFor(string $phone): string
    {
        $code = $this->sink()->codeFor($phone);
        $this->assertNotNull($code);

        return $code;
    }

    private function sink(): FakeCodeSink
    {
        return $this->app->make(FakeCodeSink::class);
    }

    private function assertRefused(TestResponse $response, string $code): void
    {
        $response->assertStatus(401)->assertJsonPath('code', $code);
        $this->assertStringNotContainsString('token', (string) $response->getContent());
    }
}
