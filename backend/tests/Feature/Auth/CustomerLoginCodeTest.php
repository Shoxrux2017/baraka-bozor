<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\Enums\Role;
use App\Models\User;
use App\Modules\Auth\CodeDelivery\CodeDeliveryFailed;
use App\Modules\Auth\CodeDelivery\CodeDeliveryGateway;
use App\Modules\Auth\CodeDelivery\CodeUndeliverable;
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
            'resend_available_in_seconds' => 0,
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

    public function test_two_wrong_codes_are_only_invalid(): void
    {
        $this->request(self::PHONE);
        $code = $this->codeFor(self::PHONE);
        $wrong = $this->wrongCode($code);

        $this->assertRefused($this->verify(self::PHONE, $wrong), 'code_invalid');
        $this->assertRefused($this->verify(self::PHONE, $wrong), 'code_invalid');

        $this->assertSame(2, LoginChallenge::query()->sole()->failed_attempts);
        $this->verify(self::PHONE, $code)->assertOk();
    }

    public function test_the_third_wrong_code_locks_the_phone(): void
    {
        $this->request(self::PHONE);
        $code = $this->codeFor(self::PHONE);
        $wrong = $this->wrongCode($code);

        $this->verify(self::PHONE, $wrong);
        $this->verify(self::PHONE, $wrong);
        $third = $this->verify(self::PHONE, $wrong);

        $third->assertStatus(429)->assertJsonPath('code', 'code_locked')->assertHeader('Retry-After', '60');
        $this->assertSame(3, LoginChallenge::query()->sole()->failed_attempts);
        $this->assertStringNotContainsString($code, (string) $third->getContent());
        $this->assertSame(0, User::query()->count(), 'no account was created');
    }

    public function test_a_locked_phone_gets_no_new_code(): void
    {
        $this->lockPhone(self::PHONE);

        $refused = $this->request(self::PHONE);

        $refused->assertStatus(429)->assertJsonPath('code', 'code_locked');
        $retryAfter = (int) $refused->headers->get('Retry-After');
        $this->assertGreaterThanOrEqual(1, $retryAfter);
        $this->assertLessThanOrEqual(60, $retryAfter);
        $this->assertSame(1, LoginChallenge::query()->count(), 'no second challenge was created');
    }

    public function test_a_refusal_during_the_lock_costs_the_address_slot_but_not_the_hour_slot(): void
    {
        $this->lockPhone(self::PHONE);

        $refusedByLock = 0;
        do {
            $response = $this->request(self::PHONE);
            $response->assertStatus(429);
            if ($response->json('code') === 'code_locked') {
                $refusedByLock++;
            }
        } while ($response->json('code') === 'code_locked' && $refusedByLock < 20);

        $this->assertSame('rate_limited', $response->json('code'), 'refusals use up the address slots');
        $this->assertGreaterThan(0, $refusedByLock);

        $this->travel(61)->seconds();

        // One send was spent before the lock; the refusals took no hour slot,
        // so four more sends still go through and the fifth is limited.
        for ($send = 1; $send <= 4; $send++) {
            $this->request(self::PHONE)->assertOk();
        }
        $this->request(self::PHONE)->assertStatus(429)->assertJsonPath('code', 'rate_limited');
    }

    public function test_the_lock_refusal_reports_what_is_left_of_the_lock(): void
    {
        $this->lockPhone(self::PHONE);

        $this->travel(25)->seconds();

        $refused = $this->request(self::PHONE);
        $refused->assertStatus(429)->assertJsonPath('code', 'code_locked');
        $retryAfter = (int) $refused->headers->get('Retry-After');
        $this->assertGreaterThanOrEqual(34, $retryAfter);
        $this->assertLessThanOrEqual(35, $retryAfter);

        $verifyRefused = $this->verify(self::PHONE, '111111');
        $verifyRefused->assertStatus(429)->assertJsonPath('code', 'code_locked');
        $this->assertLessThanOrEqual(35, (int) $verifyRefused->headers->get('Retry-After'));
    }

    public function test_a_locked_phone_cannot_verify_even_the_right_code(): void
    {
        $code = $this->lockPhone(self::PHONE);

        $this->verify(self::PHONE, $code)
            ->assertStatus(429)
            ->assertJsonPath('code', 'code_locked')
            ->assertHeader('Retry-After');
        $this->assertSame(0, User::query()->count(), 'no account was created');
    }

    public function test_after_the_lock_only_a_new_code_opens(): void
    {
        $oldCode = $this->lockPhone(self::PHONE);

        $this->travel(61)->seconds();

        $this->assertRefused($this->verify(self::PHONE, $oldCode), 'code_attempts_exhausted');

        $this->request(self::PHONE)->assertOk();
        $newCode = $this->codeFor(self::PHONE);
        $wrong = $this->wrongCode($newCode);

        $this->assertRefused($this->verify(self::PHONE, $wrong), 'code_invalid');
        $this->assertRefused($this->verify(self::PHONE, $wrong), 'code_invalid');
        $this->verify(self::PHONE, $newCode)->assertOk();
    }

    public function test_a_test_phone_locks_like_any_other(): void
    {
        $this->configureTestPhone();
        $this->request(self::TEST_PHONE)->assertOk();

        $this->verify(self::TEST_PHONE, '111111');
        $this->verify(self::TEST_PHONE, '111111');
        $this->verify(self::TEST_PHONE, '111111')->assertStatus(429)->assertJsonPath('code', 'code_locked');

        $this->verify(self::TEST_PHONE, self::TEST_CODE)->assertStatus(429)->assertJsonPath('code', 'code_locked');
        $this->request(self::TEST_PHONE)->assertStatus(429)->assertJsonPath('code', 'code_locked');
    }

    public function test_the_lock_of_one_phone_leaves_another_alone(): void
    {
        $this->lockPhone(self::PHONE);

        $this->request('+998907777777')->assertOk();
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
        $this->request(self::PHONE)->assertStatus(503);
        $this->request(self::PHONE)->assertStatus(503);
        $this->request(self::PHONE)->assertStatus(503);
        $this->request(self::PHONE)->assertStatus(503);

        $this->request(self::PHONE)->assertStatus(429)->assertJsonPath('code', 'rate_limited');
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

    public function test_ten_requests_per_ipv6_prefix_per_minute(): void
    {
        foreach (range(1, 10) as $attempt) {
            $this->withServerVariables(['REMOTE_ADDR' => '2001:db8:5:6::'.dechex($attempt)])
                ->postJson('/api/v1/auth/customer/code/request', ['phone' => sprintf('+99890%07d', $attempt)])
                ->assertOk();
        }

        $this->withServerVariables(['REMOTE_ADDR' => '2001:db8:5:6:ffff::1'])
            ->postJson('/api/v1/auth/customer/code/request', ['phone' => '+998901111111'])
            ->assertStatus(429)
            ->assertJsonPath('code', 'rate_limited');

        $this->withServerVariables(['REMOTE_ADDR' => '2001:db8:5:7::1'])
            ->postJson('/api/v1/auth/customer/code/request', ['phone' => '+998901111111'])
            ->assertOk();
    }

    public function test_a_resend_is_sent_at_once(): void
    {
        $this->request(self::PHONE)->assertOk()->assertJsonPath('data.resend_available_in_seconds', 0);
        $first = $this->codeFor(self::PHONE);

        $this->request(self::PHONE)->assertOk()->assertJsonPath('data.resend_available_in_seconds', 0);
        $second = $this->codeFor(self::PHONE);

        $this->assertSame(1, LoginChallenge::query()->openFor(self::PHONE)->count());
        if ($first !== $second) {
            $this->assertRefused($this->verify(self::PHONE, $first), 'code_invalid');
        }
        $this->verify(self::PHONE, $second)->assertOk();
    }

    public function test_the_hour_limit_stays(): void
    {
        for ($send = 1; $send <= 5; $send++) {
            $this->request(self::PHONE)->assertOk();
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

    public function test_an_unreachable_number_is_409_and_still_costs_the_send_slot(): void
    {
        $this->app->instance(CodeDeliveryGateway::class, new class implements CodeDeliveryGateway
        {
            public function deliver(string $phone, string $code): string
            {
                throw new CodeUndeliverable('No channel reaches this number.');
            }
        });

        for ($i = 0; $i < 5; $i++) {
            $this->request(self::PHONE)->assertStatus(409)->assertJsonPath('code', 'code_delivery_unavailable');
        }
        $this->request(self::PHONE)->assertStatus(429)->assertJsonPath('code', 'rate_limited');

        $this->assertSame(0, LoginChallenge::query()->count());
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

    /**
     * Requests a code and enters three wrong ones; returns the real code.
     */
    private function lockPhone(string $phone): string
    {
        $this->request($phone)->assertOk();
        $code = $this->codeFor($phone);
        $wrong = $this->wrongCode($code);

        $this->verify($phone, $wrong);
        $this->verify($phone, $wrong);
        $this->verify($phone, $wrong)->assertStatus(429);

        return $code;
    }

    private function wrongCode(string $code): string
    {
        return $code === '111111' ? '222222' : '111111';
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
