<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Models\Enums\LegalDocumentKind;
use App\Models\Enums\Role;
use App\Models\User;
use App\Modules\Auth\Actions\RequestCustomerLoginCode;
use App\Modules\Auth\LoginCodeCheck;
use App\Modules\Auth\LoginCodeRefused;
use App\Modules\Auth\Models\LoginChallenge;
use App\Modules\Auth\TestPhones;
use App\Modules\Legal\Actions\PublishLegalDocument;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * A login code has a purpose, sign-in or account deletion (BR-ROLE-012); both
 * share the phone's attempt limit and lock (DL-94 item 3).
 */
final class LoginCodePurposeTest extends TestCase
{
    use RefreshDatabase;

    private const PHONE = '+998900000099';

    private const CODE = '000000';

    protected function setUp(): void
    {
        parent::setUp();

        config(['login_codes.test_phones' => [self::PHONE], 'login_codes.test_code' => self::CODE]);
        $this->app->forgetInstance(TestPhones::class);
    }

    public function test_a_deletion_code_never_signs_in(): void
    {
        $this->requestCode(LoginChallenge::PURPOSE_ACCOUNT_DELETION);

        $this->postJson('/api/v1/auth/customer/code/verify', ['phone' => self::PHONE, 'code' => self::CODE])
            ->assertStatus(401)
            ->assertJsonPath('code', 'code_invalid');

        $this->assertNull(LoginChallenge::query()->sole()->consumed_at, 'the deletion code is untouched');
    }

    public function test_a_login_code_request_leaves_a_deletion_code_open(): void
    {
        $this->requestCode(LoginChallenge::PURPOSE_ACCOUNT_DELETION);
        $this->requestCode(LoginChallenge::PURPOSE_CUSTOMER_LOGIN);

        $this->assertSame(1, LoginChallenge::query()->openFor(self::PHONE, LoginChallenge::PURPOSE_ACCOUNT_DELETION)->count());
        $this->assertSame(1, LoginChallenge::query()->openFor(self::PHONE)->count());
    }

    public function test_a_deletion_code_request_leaves_a_login_code_open(): void
    {
        $this->requestCode(LoginChallenge::PURPOSE_CUSTOMER_LOGIN);
        $this->requestCode(LoginChallenge::PURPOSE_ACCOUNT_DELETION);

        $this->assertSame(1, LoginChallenge::query()->openFor(self::PHONE)->count());
        $this->assertSame(1, LoginChallenge::query()->openFor(self::PHONE, LoginChallenge::PURPOSE_ACCOUNT_DELETION)->count());
    }

    public function test_a_new_deletion_code_invalidates_the_previous_deletion_code(): void
    {
        $this->requestCode(LoginChallenge::PURPOSE_ACCOUNT_DELETION);
        $this->requestCode(LoginChallenge::PURPOSE_ACCOUNT_DELETION);

        $this->assertSame(1, LoginChallenge::query()->openFor(self::PHONE, LoginChallenge::PURPOSE_ACCOUNT_DELETION)->count());
        $this->assertSame(1, LoginChallenge::query()->whereNotNull('invalidated_at')->count());
    }

    public function test_the_check_consumes_a_right_deletion_code_once(): void
    {
        $this->requestCode(LoginChallenge::PURPOSE_ACCOUNT_DELETION);
        $check = $this->app->make(LoginCodeCheck::class);

        $check->consume(self::PHONE, self::CODE, LoginChallenge::PURPOSE_ACCOUNT_DELETION);

        $this->assertNotNull(LoginChallenge::query()->sole()->consumed_at);

        try {
            $check->consume(self::PHONE, self::CODE, LoginChallenge::PURPOSE_ACCOUNT_DELETION);
            $this->fail('a consumed code must not serve twice');
        } catch (LoginCodeRefused $refusal) {
            $this->assertSame('code_invalid', $refusal->apiCode);
        }
    }

    public function test_the_lock_is_shared(): void
    {
        $this->requestCode(LoginChallenge::PURPOSE_ACCOUNT_DELETION);
        $check = $this->app->make(LoginCodeCheck::class);

        foreach ([1, 2] as $attempt) {
            try {
                $check->consume(self::PHONE, '111111', LoginChallenge::PURPOSE_ACCOUNT_DELETION);
                $this->fail('a wrong code must be refused');
            } catch (LoginCodeRefused $refusal) {
                $this->assertSame('code_invalid', $refusal->apiCode, "attempt {$attempt}");
            }
        }

        try {
            $check->consume(self::PHONE, '111111', LoginChallenge::PURPOSE_ACCOUNT_DELETION);
            $this->fail('the third wrong code must lock');
        } catch (LoginCodeRefused $refusal) {
            $this->assertSame('code_locked', $refusal->apiCode);
            $this->assertSame(60, $refusal->retryAfterSeconds);
        }

        $this->postJson('/api/v1/auth/customer/code/request', ['phone' => self::PHONE])
            ->assertStatus(429)
            ->assertJsonPath('code', 'code_locked');
    }

    public function test_without_a_published_document_the_consent_time_stays_empty(): void
    {
        $admin = User::factory()->role(Role::Admin)->create();
        app(PublishLegalDocument::class)->publish($admin, LegalDocumentKind::Terms, 'uz', null);

        $this->requestCode(LoginChallenge::PURPOSE_CUSTOMER_LOGIN);
        $this->verifyLogin()->assertOk();

        $this->assertNull(User::query()->where('phone', self::PHONE)->sole()->terms_accepted_at);
    }

    public function test_verifying_records_the_consent_time(): void
    {
        $first = Carbon::parse('2026-10-19 10:00:00');
        Carbon::setTestNow($first);

        try {
            $admin = User::factory()->role(Role::Admin)->create();
            app(PublishLegalDocument::class)->publish($admin, LegalDocumentKind::Privacy, 'ru', 'Text');

            $this->requestCode(LoginChallenge::PURPOSE_CUSTOMER_LOGIN);
            $this->verifyLogin()->assertOk();

            $customer = User::query()->where('phone', self::PHONE)->sole();
            $this->assertTrue($first->equalTo($customer->terms_accepted_at));

            $later = $first->copy()->addDay();
            Carbon::setTestNow($later);

            $this->requestCode(LoginChallenge::PURPOSE_CUSTOMER_LOGIN);
            $this->verifyLogin()->assertOk();

            $this->assertTrue($later->equalTo($customer->refresh()->terms_accepted_at));
        } finally {
            Carbon::setTestNow();
        }
    }

    private function requestCode(string $purpose): void
    {
        $this->app->make(RequestCustomerLoginCode::class)(self::PHONE, '203.0.113.7', $purpose);
    }

    private function verifyLogin(): TestResponse
    {
        return $this->postJson('/api/v1/auth/customer/code/verify', ['phone' => self::PHONE, 'code' => self::CODE]);
    }
}
