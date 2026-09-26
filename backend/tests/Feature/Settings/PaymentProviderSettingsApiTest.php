<?php

declare(strict_types=1);

namespace Tests\Feature\Settings;

use App\Models\Enums\PaymentProvider;
use App\Models\Enums\Role;
use App\Models\PaymentProviderSetting;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * `GET /api/v1/admin/settings/payment-providers` and
 * `PATCH /api/v1/admin/settings/payment-providers/{provider}` (`docs/09`
 * section 44, `BR-SET-004`).
 */
final class PaymentProviderSettingsApiTest extends TestCase
{
    use RefreshDatabase;

    private const URL = '/api/v1/admin/settings/payment-providers';

    public function test_the_four_providers_are_listed_in_order_disabled_and_without_any_secret(): void
    {
        $response = $this->asAdmin()->getJson(self::URL)->assertOk();

        $this->assertSame(['payme', 'click', 'paynet', 'xazna'], array_column($response->json('data'), 'provider'));
        $this->assertSame([false, false, false, false], array_column($response->json('data'), 'is_enabled'));
        foreach ($response->json('data') as $row) {
            $this->assertSame(['provider', 'is_enabled', 'updated_at'], array_keys($row));
        }
    }

    public function test_an_admin_enables_and_disables_one_provider_and_is_recorded(): void
    {
        $admin = User::factory()->role(Role::Admin)->create();

        $this->asAdmin($admin)->patchJson(self::URL.'/payme', ['is_enabled' => true])
            ->assertOk()
            ->assertJsonPath('data.provider', 'payme')
            ->assertJsonPath('data.is_enabled', true);

        $payme = PaymentProviderSetting::query()->findOrFail(PaymentProvider::Payme->value);
        $this->assertTrue($payme->is_enabled);
        $this->assertSame($admin->id, $payme->updated_by_user_id);
        $this->assertFalse(PaymentProviderSetting::query()->findOrFail(PaymentProvider::Click->value)->is_enabled);

        $this->asAdmin($admin)->patchJson(self::URL.'/payme', ['is_enabled' => false])
            ->assertOk()
            ->assertJsonPath('data.is_enabled', false);
    }

    public function test_an_unknown_provider_is_a_scope_safe_not_found(): void
    {
        $this->asAdmin()->patchJson(self::URL.'/stripe', ['is_enabled' => true])
            ->assertStatus(404)
            ->assertJsonPath('code', 'resource_not_found');
        $this->asAdmin()->patchJson(self::URL.'/PAYME', ['is_enabled' => true])
            ->assertStatus(404);
    }

    public function test_the_body_is_a_strict_boolean_and_nothing_else(): void
    {
        foreach ([['is_enabled' => 'true'], ['is_enabled' => 1], [], ['is_enabled' => true, 'merchant_key' => 'x']] as $body) {
            $this->asAdmin()->patchJson(self::URL.'/click', $body)
                ->assertStatus(422)
                ->assertJsonPath('code', 'validation_failed');
        }

        $this->assertFalse(PaymentProviderSetting::query()->findOrFail(PaymentProvider::Click->value)->is_enabled);
    }

    public function test_every_role_but_admin_is_refused(): void
    {
        foreach ([Role::Operator, Role::Manager, Role::Customer] as $role) {
            $token = User::factory()->role($role)->create()->createToken('t')->plainTextToken;

            $this->withToken($token)->getJson(self::URL)->assertStatus(403);
            $this->withToken($token)->patchJson(self::URL.'/payme', ['is_enabled' => true])->assertStatus(403);
        }

        $this->assertFalse(PaymentProviderSetting::query()->findOrFail(PaymentProvider::Payme->value)->is_enabled);
    }

    private function asAdmin(?User $admin = null): self
    {
        $admin ??= User::factory()->role(Role::Admin)->create();

        return $this->withToken($admin->createToken('t')->plainTextToken);
    }
}
