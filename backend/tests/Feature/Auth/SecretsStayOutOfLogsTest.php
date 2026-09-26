<?php

declare(strict_types=1);

namespace Tests\Feature\Auth;

use App\Exceptions\QueryFailureReport;
use App\Models\Enums\Role;
use App\Models\User;
use App\Modules\Auth\CodeDelivery\CodeDeliveryGateway;
use App\Modules\Auth\CodeDelivery\FakeCodeSink;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Log\Events\MessageLogged;
use Illuminate\Support\Facades\Event;
use RuntimeException;
use Tests\TestCase;
use Throwable;

/**
 * `AGENTS.md` section 5, `DL-25` (8): a password or a login code never
 * reaches a log, even when something fails after it was checked and the
 * failure is logged with its stack trace.
 *
 * The container's PHP keeps argument values out of every trace; this test
 * turns that back on, so what it proves is that the parameters carrying a
 * secret are marked sensitive — the protection that holds wherever the code
 * runs.
 */
final class SecretsStayOutOfLogsTest extends TestCase
{
    use RefreshDatabase;

    private const PHONE = '+998901112233';

    /** @var list<string> */
    private array $logged = [];

    private string|false $ignoreArgs = false;

    protected function setUp(): void
    {
        parent::setUp();

        $this->ignoreArgs = ini_get('zend.exception_ignore_args');
        ini_set('zend.exception_ignore_args', '0');

        Event::listen(MessageLogged::class, function (MessageLogged $event): void {
            $context = $event->context;
            $exception = $context['exception'] ?? null;
            unset($context['exception']);

            $entry = $event->message.' '.json_encode($context);
            for ($e = $exception; $e instanceof Throwable; $e = $e->getPrevious()) {
                $entry .= ' '.$e;
            }
            $this->logged[] = $entry;
        });
    }

    protected function tearDown(): void
    {
        ini_set('zend.exception_ignore_args', $this->ignoreArgs === false ? '0' : $this->ignoreArgs);

        parent::tearDown();
    }

    public function test_a_staff_password_stays_out_of_the_log_when_the_login_fails_after_the_check(): void
    {
        $password = 'Tmp7pQx9KmT3';
        User::factory()->role(Role::Operator)->create(['phone' => self::PHONE, 'password' => $password]);
        User::updating(static function (): void {
            throw new RuntimeException('The database went away.');
        });

        $this->postJson('/api/v1/auth/staff/login', ['phone' => self::PHONE, 'password' => $password])
            ->assertStatus(500);

        $this->assertLoggedWithout($password);
    }

    public function test_both_passwords_stay_out_of_the_log_when_a_password_change_fails(): void
    {
        $current = 'Tmp7pQx9KmT3';
        $new = 'MyNewSecret1';
        $user = User::factory()->role(Role::Courier)->mustChangePassword()->create(['password' => $current]);
        $token = $user->createToken('t')->plainTextToken;
        User::updating(static function (): void {
            throw new RuntimeException('The database went away.');
        });

        $this->withToken($token)->postJson('/api/v1/auth/change-password', [
            'current_password' => $current,
            'new_password' => $new,
            'new_password_confirmation' => $new,
        ])->assertStatus(500);

        $this->assertLoggedWithout($current, $new);
    }

    public function test_a_login_code_stays_out_of_the_log_when_verification_fails_after_the_check(): void
    {
        $this->postJson('/api/v1/auth/customer/code/request', ['phone' => self::PHONE])->assertOk();
        $code = (string) $this->app->make(FakeCodeSink::class)->codeFor(self::PHONE);
        $this->assertSame(6, strlen($code));
        User::creating(static function (): void {
            throw new RuntimeException('The database went away.');
        });

        $this->postJson('/api/v1/auth/customer/code/verify', ['phone' => self::PHONE, 'code' => $code])
            ->assertStatus(500);

        $this->assertLoggedWithout($code);
    }

    public function test_a_login_code_stays_out_of_the_log_when_its_delivery_fails(): void
    {
        $gateway = new class implements CodeDeliveryGateway
        {
            public string $code = '';

            public function deliver(string $phone, #[\SensitiveParameter] string $code): string
            {
                $this->code = $code;

                throw new RuntimeException('The provider went away.');
            }
        };
        $this->app->instance(CodeDeliveryGateway::class, $gateway);

        $this->postJson('/api/v1/auth/customer/code/request', ['phone' => self::PHONE])->assertStatus(500);

        $this->assertSame(6, strlen($gateway->code));
        $this->assertLoggedWithout($gateway->code);
    }

    public function test_a_failed_query_names_the_statement_and_the_constraint_but_not_the_row(): void
    {
        // Argument values in a trace are the container setting's to keep out;
        // this test is about the query's values and PostgreSQL's quote of the
        // refused row, so it runs with the setting as deployed.
        ini_set('zend.exception_ignore_args', '1');
        $admin = User::factory()->role(Role::Admin)->create();
        User::creating(static function (User $user): void {
            // A value the database refuses, so the insert itself fails.
            $user->forceFill(['phone' => 'not a phone']);
        });

        $this->withToken($admin->createToken('t')->plainTextToken)->postJson('/api/v1/admin/staff', [
            'full_name' => 'Dilnoza Karimova',
            'phone' => self::PHONE,
            'role' => 'shopper',
        ])->assertStatus(500);

        $this->assertLoggedWithout('Dilnoza', 'not a phone', self::PHONE, '$2y$');
        $log = implode("\n", $this->logged);
        $this->assertStringContainsString('users_phone_format_check', $log);
        $this->assertStringContainsString('insert into', $log);
    }

    public function test_a_duplicate_key_is_named_without_the_key_value(): void
    {
        $message = "SQLSTATE[23505]: Unique violation: 7 ERROR:  duplicate key value violates unique constraint \"users_phone_active_staff_unique\"\nDETAIL:  Key (phone)=(+998901112233) already exists.";

        $this->assertSame(
            'SQLSTATE[23505]: Unique violation: 7 ERROR:  duplicate key value violates unique constraint "users_phone_active_staff_unique"',
            QueryFailureReport::withoutDetail($message),
        );
    }

    private function assertLoggedWithout(string ...$secrets): void
    {
        $this->assertNotEmpty($this->logged, 'The failure was expected to be logged.');

        foreach ($this->logged as $entry) {
            foreach ($secrets as $secret) {
                $this->assertStringNotContainsString($secret, $entry);
            }
        }
    }
}
