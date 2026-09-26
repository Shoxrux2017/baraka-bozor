<?php

declare(strict_types=1);

namespace Tests\Feature\Staff;

use App\Exceptions\ApiException;
use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\PushDevice;
use App\Models\User;
use App\Modules\Staff\Actions\BlockStaff;
use App\Modules\Staff\StaffDirectory;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Log\Events\MessageLogged;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use PDOException;
use Symfony\Component\HttpFoundation\Response;
use Tests\TestCase;

/**
 * Staff management (`docs/09` section 43, `docs/04` section 32,
 * `BR-ROLE-002` to `BR-ROLE-010`, `DL-17` (8), `DL-25`).
 */
final class AdminStaffApiTest extends TestCase
{
    use RefreshDatabase;

    private const URL = '/api/v1/admin/staff';

    private const PHONE = '+998901112233';

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();

        $this->admin = User::factory()->role(Role::Admin)->create(['phone' => '+998900000001']);
    }

    public function test_admin_creates_a_staff_account_with_a_temporary_password_shown_once(): void
    {
        $response = $this->asAdmin()->postJson(self::URL, [
            'full_name' => '  Dilnoza Karimova ',
            'phone' => self::PHONE,
            'role' => 'shopper',
        ])->assertCreated();

        $this->assertStringContainsString('no-store', (string) $response->headers->get('Cache-Control'));
        $this->assertSame(['user', 'temporary_password'], array_keys($response->json('data')));
        $this->assertSame([
            'id', 'role', 'phone', 'full_name', 'status', 'must_change_password',
            'last_login_at', 'blocked_at', 'created_at', 'updated_at',
        ], array_keys($response->json('data.user')));
        $response->assertJsonPath('data.user.role', 'shopper')
            ->assertJsonPath('data.user.full_name', 'Dilnoza Karimova')
            ->assertJsonPath('data.user.status', 'active')
            ->assertJsonPath('data.user.must_change_password', true)
            ->assertJsonPath('data.user.last_login_at', null);

        $password = (string) $response->json('data.temporary_password');
        $this->assertMatchesRegularExpression('/^[2-9A-HJ-NP-Za-km-np-z]{12}$/', $password);

        $staff = User::query()->findOrFail($response->json('data.user.id'));
        $this->assertSame(Role::Shopper, $staff->role);
        $this->assertSame($this->admin->id, $staff->created_by_user_id);
        $this->assertNull($staff->password_changed_at);
        $this->assertNotSame($password, $staff->password);
        $this->assertTrue(Hash::check($password, (string) $staff->password));

        $this->asAdmin()->getJson(self::URL.'/'.$staff->id)->assertOk()->assertJsonMissingPath('data.temporary_password');

        $this->login(self::PHONE, $password)
            ->assertOk()
            ->assertJsonPath('data.user.must_change_password', true);
    }

    public function test_the_temporary_password_reaches_neither_a_log_nor_the_database_in_clear(): void
    {
        $logged = [];
        Event::listen(MessageLogged::class, function (MessageLogged $event) use (&$logged): void {
            $logged[] = $event->message.' '.json_encode($event->context);
        });
        DB::enableQueryLog();

        $created = (string) $this->asAdmin()->postJson(self::URL, $this->body())->json('data.temporary_password');
        $staffId = (string) User::query()->where('phone', self::PHONE)->value('id');
        $reset = (string) $this->asAdmin()->postJson(self::URL.'/'.$staffId.'/reset-password')->json('data.temporary_password');

        $queries = json_encode(DB::getQueryLog());
        DB::disableQueryLog();

        foreach ([$created, $reset] as $password) {
            $this->assertSame(12, strlen($password));
            $this->assertStringNotContainsString($password, (string) $queries);

            foreach ($logged as $entry) {
                $this->assertStringNotContainsString($password, $entry);
            }
        }
    }

    public function test_create_refuses_a_customer_role_a_bad_phone_a_bad_name_and_undeclared_fields(): void
    {
        foreach ([
            'role' => ['customer', 'root', '', null],
            'phone' => ['998901112233', '+99890111223', '+9989011122334', '+998 90 111 22 33', '', 901112233],
            'full_name' => ['', '   ', null, str_repeat('a', 121)],
            'status' => ['blocked'],
            'must_change_password' => [false],
            'password' => ['chosen-by-admin'],
        ] as $field => $values) {
            foreach ($values as $value) {
                $this->asAdmin()->postJson(self::URL, $this->body([$field => $value]))
                    ->assertStatus(422)
                    ->assertJsonPath('code', 'validation_failed')
                    ->assertJsonValidationErrorFor($field, 'errors');
            }
        }

        $this->assertFalse(User::query()->where('phone', self::PHONE)->exists());
    }

    public function test_every_staff_role_can_be_created_and_a_name_of_120_characters_fits(): void
    {
        foreach ([Role::Shopper, Role::Courier, Role::Operator, Role::Admin, Role::Manager] as $index => $role) {
            $this->asAdmin()->postJson(self::URL, [
                'full_name' => str_repeat('я', 120),
                'phone' => '+99890111220'.$index,
                'role' => $role->value,
            ])->assertCreated()->assertJsonPath('data.user.role', $role->value);
        }
    }

    public function test_one_active_staff_account_per_phone(): void
    {
        User::factory()->role(Role::Courier)->create(['phone' => self::PHONE]);

        $this->asAdmin()->postJson(self::URL, $this->body())
            ->assertStatus(409)
            ->assertJsonPath('code', 'phone_already_active');
        $this->assertSame(1, User::query()->where('phone', self::PHONE)->count());
    }

    public function test_a_create_that_loses_the_phone_to_a_concurrent_one_is_the_same_conflict(): void
    {
        // Another request's account takes the phone after this one checked
        // it and before its insert: the unique index decides.
        User::creating(static function (User $user): void {
            if ($user->role === Role::Shopper) {
                User::factory()->role(Role::Courier)->create(['phone' => self::PHONE]);
            }
        });

        $this->asAdmin()->postJson(self::URL, $this->body())
            ->assertStatus(409)
            ->assertJsonPath('code', 'phone_already_active');

        $this->assertFalse(User::query()->where('role', Role::Shopper->value)->exists());
    }

    public function test_an_activate_that_loses_the_phone_to_a_concurrent_one_is_the_same_conflict(): void
    {
        $old = User::factory()->role(Role::Shopper)->blocked()->create(['phone' => self::PHONE]);
        User::updating(static function (User $user) use ($old): void {
            if ($user->is($old)) {
                User::factory()->role(Role::Courier)->create(['phone' => self::PHONE]);
            }
        });

        $this->asAdmin()->postJson(self::URL.'/'.$old->id.'/activate')
            ->assertStatus(409)
            ->assertJsonPath('code', 'phone_already_active');

        $this->assertSame(UserStatus::Blocked, $old->fresh()?->status);
    }

    public function test_another_unique_violation_is_not_mistaken_for_the_phone_rule(): void
    {
        $clash = new UniqueConstraintViolationException('pgsql', 'insert', [], new PDOException('duplicate'));

        $this->assertFalse(StaffDirectory::isActivePhoneClash($clash->setIndex('users_pkey')));
        $this->assertTrue(StaffDirectory::isActivePhoneClash($clash->setIndex(StaffDirectory::ACTIVE_PHONE_INDEX)));
    }

    public function test_a_blocked_staff_account_or_a_customer_on_the_phone_does_not_stop_a_create(): void
    {
        User::factory()->role(Role::Shopper)->blocked()->create(['phone' => self::PHONE]);
        User::factory()->customer()->create(['phone' => self::PHONE]);

        $this->asAdmin()->postJson(self::URL, $this->body(['role' => 'courier']))->assertCreated();
    }

    public function test_the_list_holds_staff_only_newest_first_and_filters_by_role_and_status(): void
    {
        $shopper = User::factory()->role(Role::Shopper)->create(['created_at' => Carbon::parse('2026-09-25 10:00:00')]);
        $blockedCourier = User::factory()->role(Role::Courier)->blocked()->create(['created_at' => Carbon::parse('2026-09-24 10:00:00')]);
        $this->admin->forceFill(['created_at' => Carbon::parse('2026-09-20 10:00:00')])->save();
        User::factory()->customer()->create();

        $this->asAdmin()->getJson(self::URL)
            ->assertOk()
            ->assertJsonPath('data.*.id', [$shopper->id, $blockedCourier->id, $this->admin->id]);
        $this->asAdmin()->getJson(self::URL.'?role=courier')
            ->assertJsonPath('data.*.id', [$blockedCourier->id]);
        $this->asAdmin()->getJson(self::URL.'?status=active')
            ->assertJsonPath('data.*.id', [$shopper->id, $this->admin->id]);
        $this->asAdmin()->getJson(self::URL.'?role=shopper&status=blocked')
            ->assertJsonPath('meta.pagination.total', 0);
        $this->asAdmin()->getJson(self::URL.'?per_page=1&page=3')
            ->assertJsonPath('data.*.id', [$this->admin->id]);
        $this->asAdmin()->getJson(self::URL.'?role=&status=')->assertJsonPath('meta.pagination.total', 3);

        foreach (['role=customer', 'role=boss', 'status=deleted'] as $query) {
            $this->asAdmin()->getJson(self::URL.'?'.$query)->assertStatus(422);
        }
    }

    public function test_a_customer_or_a_missing_id_is_not_found_on_every_staff_endpoint(): void
    {
        $customer = User::factory()->customer()->create(['full_name' => 'Mijoz']);

        foreach ([$customer->id, (string) Str::uuid()] as $id) {
            $url = self::URL.'/'.$id;

            foreach ([
                $this->asAdmin()->getJson($url),
                $this->asAdmin()->patchJson($url, ['full_name' => 'X']),
                $this->asAdmin()->postJson($url.'/block'),
                $this->asAdmin()->postJson($url.'/activate'),
                $this->asAdmin()->postJson($url.'/reset-password'),
            ] as $response) {
                $response->assertStatus(404)->assertJsonPath('code', 'resource_not_found');
            }
        }

        $fresh = $customer->fresh();
        $this->assertNotNull($fresh);
        $this->assertSame('Mijoz', $fresh->full_name);
        $this->assertSame(UserStatus::Active, $fresh->status);
    }

    public function test_an_edit_changes_the_name_and_nothing_else(): void
    {
        $staff = User::factory()->role(Role::Courier)->create(['full_name' => 'Eski', 'phone' => self::PHONE]);
        $url = self::URL.'/'.$staff->id;

        $this->asAdmin()->patchJson($url, ['full_name' => ' Yangi Ism '])
            ->assertOk()
            ->assertJsonPath('data.full_name', 'Yangi Ism')
            ->assertJsonPath('data.role', 'courier');

        foreach ([['role' => 'admin'], ['phone' => '+998909998877'], ['status' => 'blocked'], ['full_name' => '']] as $body) {
            $this->asAdmin()->patchJson($url, $body)
                ->assertStatus(422)
                ->assertJsonValidationErrorFor((string) array_key_first($body), 'errors');
        }
        $this->asAdmin()->patchJson($url, [])->assertStatus(422)->assertJsonValidationErrorFor('body', 'errors');

        $fresh = $staff->fresh();
        $this->assertNotNull($fresh);
        $this->assertSame(Role::Courier, $fresh->role);
        $this->assertSame(self::PHONE, $fresh->phone);
        $this->assertSame('Yangi Ism', $fresh->full_name);
    }

    public function test_block_ends_every_session_of_the_account_at_once(): void
    {
        $staff = User::factory()->role(Role::Operator)->create(['phone' => self::PHONE, 'password' => 'secret-password']);
        $phoneToken = $staff->createToken('phone')->plainTextToken;
        $tabletToken = $staff->createToken('tablet')->plainTextToken;
        $this->withToken($phoneToken)->getJson('/api/v1/auth/me')->assertOk();

        $this->asAdmin()->postJson(self::URL.'/'.$staff->id.'/block')
            ->assertOk()
            ->assertJsonPath('data.status', 'blocked');

        $this->assertNotNull($staff->fresh()?->blocked_at);
        $this->assertSame(0, $staff->tokens()->count());
        foreach ([$phoneToken, $tabletToken] as $token) {
            $this->withToken($token)->getJson('/api/v1/auth/me')->assertStatus(401);
        }
        $this->withoutToken();
        $this->login(self::PHONE, 'secret-password')->assertStatus(401)->assertJsonPath('code', 'account_blocked');
    }

    public function test_block_and_reset_revoke_every_push_device_of_the_account_and_no_other(): void
    {
        $blocked = User::factory()->role(Role::Courier)->create();
        $reset = User::factory()->role(Role::Shopper)->create();
        $bystander = User::factory()->role(Role::Shopper)->create();
        $devices = [
            PushDevice::factory()->create(['user_id' => $blocked->id]),
            PushDevice::factory()->create(['user_id' => $blocked->id]),
            PushDevice::factory()->create(['user_id' => $reset->id]),
        ];
        $untouched = PushDevice::factory()->create(['user_id' => $bystander->id]);

        $this->asAdmin()->postJson(self::URL.'/'.$blocked->id.'/block')->assertOk();
        $this->asAdmin()->postJson(self::URL.'/'.$reset->id.'/reset-password')->assertOk();

        foreach ($devices as $device) {
            $this->assertNotNull($device->fresh()?->revoked_at);
        }
        $this->assertNull($untouched->fresh()?->revoked_at);
    }

    public function test_blocking_a_blocked_account_is_a_natural_repeat(): void
    {
        $blockedAt = Carbon::parse('2026-09-20 08:00:00');
        $staff = User::factory()->role(Role::Shopper)->blocked()->create(['blocked_at' => $blockedAt]);

        $this->asAdmin()->postJson(self::URL.'/'.$staff->id.'/block')
            ->assertOk()
            ->assertJsonPath('data.status', 'blocked')
            ->assertJsonPath('data.blocked_at', '2026-09-20T08:00:00Z');
    }

    public function test_an_admin_cannot_block_themselves(): void
    {
        $this->asAdmin()->postJson(self::URL.'/'.$this->admin->id.'/block')
            ->assertStatus(409)
            ->assertJsonPath('code', 'self_block_not_allowed');

        $this->assertSame(UserStatus::Active, $this->admin->fresh()?->status);
    }

    public function test_another_admin_can_be_blocked_while_one_active_admin_remains(): void
    {
        $other = User::factory()->role(Role::Admin)->create();

        $this->asAdmin()->postJson(self::URL.'/'.$other->id.'/block')->assertOk();
    }

    public function test_the_last_active_admin_is_never_blocked(): void
    {
        // Two Admins block each other at the same instant: by the time the
        // second block runs, the first has blocked its author. The request
        // passed the session check before that, so the action is called here
        // with the author as the check left it.
        $author = User::factory()->role(Role::Admin)->blocked()->create();

        try {
            app(BlockStaff::class)($author, $this->admin->id);
            $this->fail('The last active Admin was blocked.');
        } catch (ApiException $refusal) {
            $this->assertSame('last_active_admin_required', $refusal->apiCode());
        }

        $this->assertSame(UserStatus::Active, $this->admin->fresh()?->status);
    }

    public function test_activate_restores_an_account_and_its_password(): void
    {
        $staff = User::factory()->role(Role::Courier)->blocked()->create(['phone' => self::PHONE, 'password' => 'secret-password']);

        $this->asAdmin()->postJson(self::URL.'/'.$staff->id.'/activate')
            ->assertOk()
            ->assertJsonPath('data.status', 'active')
            ->assertJsonPath('data.blocked_at', null);
        $this->asAdmin()->postJson(self::URL.'/'.$staff->id.'/activate')
            ->assertOk()
            ->assertJsonPath('data.status', 'active');

        $this->withoutToken();
        $this->login(self::PHONE, 'secret-password')->assertOk();
    }

    public function test_activate_is_refused_while_another_active_staff_account_holds_the_phone(): void
    {
        // A role change: the old Shopper account was blocked and a Courier
        // account created on the same phone (`BR-ROLE-002`).
        $old = User::factory()->role(Role::Shopper)->blocked()->create(['phone' => self::PHONE]);
        User::factory()->role(Role::Courier)->create(['phone' => self::PHONE]);
        User::factory()->customer()->create(['phone' => '+998907776655']);

        $this->asAdmin()->postJson(self::URL.'/'.$old->id.'/activate')
            ->assertStatus(409)
            ->assertJsonPath('code', 'phone_already_active');
        $this->assertSame(UserStatus::Blocked, $old->fresh()?->status);

        $blockedOnCustomerPhone = User::factory()->role(Role::Shopper)->blocked()->create(['phone' => '+998907776655']);
        $this->asAdmin()->postJson(self::URL.'/'.$blockedOnCustomerPhone->id.'/activate')->assertOk();
    }

    public function test_reset_issues_a_new_temporary_password_sets_the_gate_and_ends_every_session(): void
    {
        $staff = User::factory()->role(Role::Operator)->create([
            'phone' => self::PHONE,
            'password' => 'old-password',
            'must_change_password' => false,
            'password_changed_at' => now(),
        ]);
        $token = $staff->createToken('phone')->plainTextToken;

        $response = $this->asAdmin()->postJson(self::URL.'/'.$staff->id.'/reset-password')
            ->assertOk()
            ->assertJsonPath('data.user.id', $staff->id)
            ->assertJsonPath('data.user.must_change_password', true);
        $this->assertStringContainsString('no-store', (string) $response->headers->get('Cache-Control'));
        $password = (string) $response->json('data.temporary_password');
        $this->assertMatchesRegularExpression('/^[2-9A-HJ-NP-Za-km-np-z]{12}$/', $password);

        $this->withToken($token)->getJson('/api/v1/auth/me')->assertStatus(401);
        $this->withoutToken();
        $this->assertNull($staff->fresh()?->password_changed_at);
        $this->login(self::PHONE, 'old-password')->assertStatus(401)->assertJsonPath('code', 'invalid_credentials');
        $this->login(self::PHONE, $password)->assertOk()->assertJsonPath('data.user.must_change_password', true);

        $second = (string) $this->asAdmin()->postJson(self::URL.'/'.$staff->id.'/reset-password')->json('data.temporary_password');
        $this->assertNotSame($password, $second);
    }

    public function test_a_blocked_account_may_be_reset_but_an_admin_never_resets_themselves(): void
    {
        $blocked = User::factory()->role(Role::Shopper)->blocked()->create();

        $this->asAdmin()->postJson(self::URL.'/'.$blocked->id.'/reset-password')
            ->assertOk()
            ->assertJsonPath('data.user.status', 'blocked');

        $this->asAdmin()->postJson(self::URL.'/'.$this->admin->id.'/reset-password')
            ->assertStatus(409)
            ->assertJsonPath('code', 'self_reset_not_allowed');
        $this->assertTrue(Hash::check('password', (string) $this->admin->fresh()?->password));
    }

    public function test_every_role_but_admin_is_refused(): void
    {
        $staff = User::factory()->role(Role::Shopper)->create();

        foreach ([Role::Operator, Role::Manager, Role::Shopper, Role::Courier, Role::Customer] as $role) {
            $token = User::factory()->role($role)->create()->createToken('t')->plainTextToken;
            $url = self::URL.'/'.$staff->id;

            foreach ([
                $this->withToken($token)->getJson(self::URL),
                $this->withToken($token)->postJson(self::URL, $this->body()),
                $this->withToken($token)->getJson($url),
                $this->withToken($token)->patchJson($url, ['full_name' => 'X']),
                $this->withToken($token)->postJson($url.'/block'),
                $this->withToken($token)->postJson($url.'/activate'),
                $this->withToken($token)->postJson($url.'/reset-password'),
            ] as $response) {
                $response->assertStatus(403)->assertJsonPath('code', 'forbidden');
            }
        }

        $this->assertSame(UserStatus::Active, $staff->fresh()?->status);
        $this->assertFalse(User::query()->where('phone', self::PHONE)->exists());
    }

    public function test_an_admin_behind_the_password_gate_manages_nobody(): void
    {
        $gated = User::factory()->role(Role::Admin)->mustChangePassword()->create();

        $this->withToken($gated->createToken('t')->plainTextToken)->postJson(self::URL, $this->body())
            ->assertStatus(403)
            ->assertJsonPath('code', 'password_change_required');
    }

    public function test_without_a_token_the_answer_is_authentication_required(): void
    {
        $this->getJson(self::URL)->assertStatus(401)->assertJsonPath('code', 'authentication_required');
        $this->postJson(self::URL, $this->body())->assertStatus(401);
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function body(array $overrides = []): array
    {
        return array_merge(['full_name' => 'Dilnoza Karimova', 'phone' => self::PHONE, 'role' => 'shopper'], $overrides);
    }

    /**
     * @return TestResponse<Response>
     */
    private function login(string $phone, string $password): TestResponse
    {
        return $this->postJson('/api/v1/auth/staff/login', ['phone' => $phone, 'password' => $password]);
    }

    private function asAdmin(): self
    {
        return $this->withToken($this->admin->createToken('t')->plainTextToken);
    }
}
