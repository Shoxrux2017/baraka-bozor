<?php

declare(strict_types=1);

namespace Tests\Feature\Settings;

use App\Models\BusinessSettings;
use App\Models\Enums\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * `GET|PATCH /api/v1/admin/settings/business` (`docs/09` section 44,
 * `BR-SET-001`).
 */
final class BusinessSettingsApiTest extends TestCase
{
    use RefreshDatabase;

    private const URL = '/api/v1/admin/settings/business';

    public function test_an_admin_reads_every_setting_with_nothing_configured_yet(): void
    {
        $response = $this->asAdmin()->getJson(self::URL)->assertOk();

        $this->assertSame([
            'markup_percent', 'service_fee_mode', 'service_fee_fixed_uzs', 'service_fee_percent',
            'delivery_fee_uzs', 'minimum_order_uzs', 'price_tolerance_percent', 'opens_at', 'closes_at',
            'service_centre_latitude', 'service_centre_longitude', 'service_radius_km',
            'delivery_delay_threshold_minutes', 'updated_at',
        ], array_keys($response->json('data')), 'Exactly the settings, nothing internal such as the id or the last editor.');
        $this->assertMatchesRegularExpression('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/', $response->json('data.updated_at'));

        $response
            ->assertJson(['data' => [
                'markup_percent' => '0.00',
                'service_fee_mode' => 'fixed',
                'service_fee_fixed_uzs' => null,
                'service_fee_percent' => null,
                'delivery_fee_uzs' => null,
                'minimum_order_uzs' => null,
                'price_tolerance_percent' => '15.00',
                'opens_at' => null,
                'closes_at' => null,
                'service_centre_latitude' => null,
                'service_centre_longitude' => null,
                'service_radius_km' => null,
                'delivery_delay_threshold_minutes' => 60,
            ]]);
    }

    public function test_every_role_but_admin_is_refused_and_no_token_is_unauthenticated(): void
    {
        foreach ([Role::Operator, Role::Manager, Role::Shopper, Role::Courier, Role::Customer] as $role) {
            $user = User::factory()->role($role)->create();

            $this->withToken($user->createToken('t')->plainTextToken)->getJson(self::URL)
                ->assertStatus(403)
                ->assertJsonPath('code', 'forbidden');
            $this->withToken($user->createToken('t')->plainTextToken)->patchJson(self::URL, ['markup_percent' => '10'])
                ->assertStatus(403)
                ->assertJsonPath('code', 'forbidden');
        }

        $this->withoutToken()->getJson(self::URL)->assertStatus(401)->assertJsonPath('code', 'authentication_required');
        $this->assertSame('0.00', BusinessSettings::current()->markup_percent);
    }

    public function test_a_subset_is_saved_the_rest_is_left_alone_and_the_admin_is_recorded(): void
    {
        $admin = User::factory()->role(Role::Admin)->create();

        $this->asAdmin($admin)->patchJson(self::URL, [
            'markup_percent' => '12.5',
            'delivery_fee_uzs' => 15_000,
            'minimum_order_uzs' => 50_000,
            'opens_at' => '08:00',
            'closes_at' => '20:00',
            'service_centre_latitude' => '41.311081',
            'service_centre_longitude' => '69.240562',
            'service_radius_km' => '12.5',
        ])
            ->assertOk()
            ->assertJsonPath('data.markup_percent', '12.50')
            ->assertJsonPath('data.delivery_fee_uzs', 15_000)
            ->assertJsonPath('data.opens_at', '08:00')
            ->assertJsonPath('data.closes_at', '20:00')
            ->assertJsonPath('data.service_centre_latitude', '41.311081')
            ->assertJsonPath('data.service_radius_km', '12.50')
            ->assertJsonPath('data.price_tolerance_percent', '15.00')
            ->assertJsonPath('data.service_fee_mode', 'fixed');

        $settings = BusinessSettings::current();
        $this->assertSame($admin->id, $settings->updated_by_user_id);
        $this->assertSame(50_000, $settings->minimum_order_uzs);

        $this->asAdmin($admin)->patchJson(self::URL, ['delivery_fee_uzs' => null])
            ->assertOk()
            ->assertJsonPath('data.delivery_fee_uzs', null)
            ->assertJsonPath('data.markup_percent', '12.50');
    }

    public function test_every_field_refuses_a_value_of_the_wrong_shape(): void
    {
        $cases = [
            'markup_percent' => ['abc', '-1', '12.345', '1000', 12.5, null],
            'service_fee_mode' => ['free', null],
            'service_fee_fixed_uzs' => [-1, '100', 1.5, 1_000_000_001],
            'service_fee_percent' => ['5.555', 5],
            'delivery_fee_uzs' => [-1, '15000'],
            'minimum_order_uzs' => [-5, true],
            'price_tolerance_percent' => ['-2', null],
            'opens_at' => ['8am', '25:00', '08:00:00'],
            'closes_at' => ['2000'],
            'service_centre_latitude' => ['91.0', '41.1234567', 41.3],
            'service_centre_longitude' => ['181', '69,24'],
            'service_radius_km' => ['0', '-1', '12.345', 12],
            'delivery_delay_threshold_minutes' => [0, 1441, '60', null],
        ];

        foreach ($cases as $field => $values) {
            foreach ($values as $value) {
                $this->asAdmin()->patchJson(self::URL, [$field => $value])
                    ->assertStatus(422)
                    ->assertJsonPath('code', 'validation_failed')
                    ->assertJsonValidationErrorFor($field, 'errors');
            }
        }

        $this->assertNull(BusinessSettings::current()->updated_by_user_id, 'Nothing was saved.');
    }

    public function test_a_body_that_names_no_setting_is_refused_and_records_nothing(): void
    {
        $this->asAdmin()->patchJson(self::URL, [])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('body', 'errors');

        $token = User::factory()->role(Role::Admin)->create()->createToken('t')->plainTextToken;
        $this->call('PATCH', self::URL, [], [], [], [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$token,
        ], '{"markup_percent": "12.5"')
            ->assertStatus(422);

        $this->assertNull(BusinessSettings::current()->updated_by_user_id);
    }

    public function test_an_unknown_field_is_refused(): void
    {
        $this->asAdmin()->patchJson(self::URL, ['test_phones' => '+998900000001'])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('test_phones', 'errors');
    }

    public function test_the_value_of_the_service_fee_mode_not_chosen_must_be_cleared(): void
    {
        $this->asAdmin()->patchJson(self::URL, ['service_fee_fixed_uzs' => 10_000])->assertOk();

        $this->asAdmin()->patchJson(self::URL, ['service_fee_mode' => 'percentage', 'service_fee_percent' => '5'])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('service_fee_fixed_uzs', 'errors');

        $this->asAdmin()->patchJson(self::URL, [
            'service_fee_mode' => 'percentage',
            'service_fee_fixed_uzs' => null,
            'service_fee_percent' => '5',
        ])
            ->assertOk()
            ->assertJsonPath('data.service_fee_mode', 'percentage')
            ->assertJsonPath('data.service_fee_percent', '5.00')
            ->assertJsonPath('data.service_fee_fixed_uzs', null);

        $this->asAdmin()->patchJson(self::URL, ['service_fee_mode' => 'fixed'])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('service_fee_percent', 'errors');
    }

    public function test_working_hours_and_the_centre_come_in_pairs(): void
    {
        $this->asAdmin()->patchJson(self::URL, ['opens_at' => '08:00'])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('closes_at', 'errors');

        $this->asAdmin()->patchJson(self::URL, ['opens_at' => '08:00', 'closes_at' => '08:00'])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('closes_at', 'errors');

        $this->asAdmin()->patchJson(self::URL, ['service_centre_longitude' => '69.240562'])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('service_centre_latitude', 'errors');

        // Closing after midnight is a pair like any other.
        $this->asAdmin()->patchJson(self::URL, ['opens_at' => '18:00', 'closes_at' => '02:00'])->assertOk();

        // Clearing both halves together is allowed.
        $this->asAdmin()->patchJson(self::URL, ['opens_at' => null, 'closes_at' => null])
            ->assertOk()
            ->assertJsonPath('data.opens_at', null);
    }

    private function asAdmin(?User $admin = null): self
    {
        $admin ??= User::factory()->role(Role::Admin)->create();

        return $this->withToken($admin->createToken('t')->plainTextToken);
    }
}
