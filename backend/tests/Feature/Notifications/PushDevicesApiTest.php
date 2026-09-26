<?php

declare(strict_types=1);

namespace Tests\Feature\Notifications;

use App\Models\Enums\PushPlatform;
use App\Models\Enums\Role;
use App\Models\PushDevice;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * Push device registration (`docs/09` section 27, `DL-17` (9), `DL-26`,
 * interview 7.0).
 */
final class PushDevicesApiTest extends TestCase
{
    use RefreshDatabase;

    private const URL = '/api/v1/push-devices';

    private const TOKEN = 'fcm-token-aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:APA91b';

    public function test_a_token_is_registered_for_the_caller(): void
    {
        $customer = User::factory()->customer()->create();

        $response = $this->as($customer)->postJson(self::URL, ['platform' => 'android', 'token' => self::TOKEN])
            ->assertOk();

        $this->assertSame(['id', 'platform', 'last_seen_at', 'created_at'], array_keys($response->json('data')));
        $response->assertJsonPath('data.platform', 'android');
        $this->assertStringNotContainsString(self::TOKEN, (string) $response->getContent());

        $device = PushDevice::query()->findOrFail($response->json('data.id'));
        $this->assertSame($customer->id, $device->user_id);
        $this->assertSame(self::TOKEN, $device->push_token);
        $this->assertSame(PushPlatform::Android, $device->platform);
        $this->assertNotNull($device->last_seen_at);
        $this->assertNull($device->revoked_at);
    }

    public function test_registering_again_refreshes_the_same_row(): void
    {
        $courier = User::factory()->role(Role::Courier)->create();

        Carbon::setTestNow('2026-09-26 09:00:00');
        $first = $this->as($courier)->postJson(self::URL, ['platform' => 'android', 'token' => self::TOKEN])->json('data.id');
        Carbon::setTestNow('2026-09-26 12:30:00');
        $this->as($courier)->postJson(self::URL, ['platform' => 'ios', 'token' => self::TOKEN])
            ->assertOk()
            ->assertJsonPath('data.id', $first)
            ->assertJsonPath('data.platform', 'ios')
            ->assertJsonPath('data.last_seen_at', '2026-09-26T12:30:00Z')
            ->assertJsonPath('data.created_at', '2026-09-26T09:00:00Z');
        Carbon::setTestNow();

        $this->assertSame(1, PushDevice::query()->count());
    }

    public function test_two_accounts_on_one_phone_register_the_same_token_twice(): void
    {
        $customer = User::factory()->customer()->create(['phone' => '+998901112233']);
        $shopper = User::factory()->role(Role::Shopper)->create(['phone' => '+998901112233']);

        $this->as($customer)->postJson(self::URL, ['platform' => 'android', 'token' => self::TOKEN])->assertOk();
        $this->as($shopper)->postJson(self::URL, ['platform' => 'android', 'token' => self::TOKEN])->assertOk();

        $owners = PushDevice::query()->where('push_token', self::TOKEN)->pluck('user_id')->all();
        $expected = [$customer->id, $shopper->id];
        sort($owners);
        sort($expected);
        $this->assertSame($expected, $owners);
    }

    public function test_a_revoked_device_comes_back_when_it_registers_again(): void
    {
        $customer = User::factory()->customer()->create();
        $id = $this->as($customer)->postJson(self::URL, ['platform' => 'android', 'token' => self::TOKEN])->json('data.id');

        $this->as($customer)->deleteJson(self::URL.'/'.$id)->assertNoContent();
        $this->assertNotNull(PushDevice::query()->findOrFail($id)->revoked_at);

        $this->as($customer)->postJson(self::URL, ['platform' => 'android', 'token' => self::TOKEN])
            ->assertOk()
            ->assertJsonPath('data.id', $id);
        $this->assertNull(PushDevice::query()->findOrFail($id)->revoked_at);
    }

    public function test_revoking_is_idempotent_for_the_owner_and_keeps_the_first_instant(): void
    {
        $customer = User::factory()->customer()->create();
        $device = PushDevice::factory()->create(['user_id' => $customer->id]);

        Carbon::setTestNow('2026-09-26 10:00:00');
        $this->as($customer)->deleteJson(self::URL.'/'.$device->id)->assertNoContent();
        Carbon::setTestNow('2026-09-26 11:00:00');
        $this->as($customer)->deleteJson(self::URL.'/'.$device->id)->assertNoContent();
        Carbon::setTestNow();

        $this->assertSame('2026-09-26 10:00:00', PushDevice::query()->findOrFail($device->id)->revoked_at?->format('Y-m-d H:i:s'));
    }

    public function test_another_accounts_device_is_not_found(): void
    {
        $owner = User::factory()->customer()->create();
        $device = PushDevice::factory()->create(['user_id' => $owner->id]);
        $stranger = User::factory()->role(Role::Admin)->create();

        foreach ([$device->id, (string) Str::uuid(), 'not-a-uuid'] as $id) {
            $this->as($stranger)->deleteJson(self::URL.'/'.$id)
                ->assertStatus(404)
                ->assertJsonPath('code', 'resource_not_found');
        }

        $this->assertNull($device->fresh()?->revoked_at);
    }

    public function test_the_platform_and_the_token_are_checked_and_the_owner_is_not_a_field(): void
    {
        $customer = User::factory()->customer()->create();
        $other = User::factory()->customer()->create();

        foreach ([
            ['platform' => 'windows', 'token' => self::TOKEN],
            ['platform' => null, 'token' => self::TOKEN],
            ['platform' => 'android', 'token' => ''],
            ['platform' => 'android', 'token' => '   '],
            ['platform' => 'android', 'token' => str_repeat('a', 513)],
            ['platform' => 'android', 'token' => 12345],
            ['platform' => 'android', 'token' => self::TOKEN, 'user_id' => $other->id],
            ['platform' => 'android', 'token' => self::TOKEN, 'revoked_at' => null],
        ] as $body) {
            $this->as($customer)->postJson(self::URL, $body)
                ->assertStatus(422)
                ->assertJsonPath('code', 'validation_failed');
        }

        $this->as($customer)->postJson(self::URL, ['platform' => 'web', 'token' => str_repeat('a', 512)])->assertOk();
        $this->assertSame(1, PushDevice::query()->count());
    }

    public function test_every_role_may_register_but_not_behind_the_password_gate(): void
    {
        foreach ([Role::Customer, Role::Shopper, Role::Courier, Role::Operator, Role::Admin, Role::Manager] as $role) {
            $this->as(User::factory()->role($role)->create())
                ->postJson(self::URL, ['platform' => 'android', 'token' => self::TOKEN])
                ->assertOk();
        }

        $gated = User::factory()->role(Role::Courier)->mustChangePassword()->create();
        $this->as($gated)->postJson(self::URL, ['platform' => 'android', 'token' => 'other-token'])
            ->assertStatus(403)
            ->assertJsonPath('code', 'password_change_required');
    }

    public function test_without_a_token_the_answer_is_authentication_required(): void
    {
        $this->postJson(self::URL, ['platform' => 'android', 'token' => self::TOKEN])
            ->assertStatus(401)
            ->assertJsonPath('code', 'authentication_required');
        $this->deleteJson(self::URL.'/'.Str::uuid())->assertStatus(401);
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
