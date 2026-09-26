<?php

declare(strict_types=1);

namespace Tests\Feature\Customer;

use App\Models\Enums\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * The Customer's own profile (`docs/09` section 12, `docs/03` section 3).
 */
final class ProfileApiTest extends TestCase
{
    use RefreshDatabase;

    private const URL = '/api/v1/customer/profile';

    public function test_the_customer_sees_exactly_their_own_profile(): void
    {
        $customer = User::factory()->customer()->create(['phone' => '+998901112233', 'full_name' => null]);
        User::factory()->customer()->create(['full_name' => 'Boshqa Mijoz']);

        $data = $this->as($customer)->getJson(self::URL)->assertOk()->json('data');

        $this->assertSame([
            'id' => $customer->id,
            'phone' => '+998901112233',
            'full_name' => null,
            'preferred_language' => 'uz',
        ], $data);
    }

    public function test_the_name_and_the_language_are_updated_and_the_name_is_trimmed(): void
    {
        $customer = User::factory()->customer()->create(['full_name' => null]);

        $this->as($customer)->patchJson(self::URL, ['full_name' => '  Aziza Karimova  '])
            ->assertOk()
            ->assertJsonPath('data.full_name', 'Aziza Karimova')
            ->assertJsonPath('data.preferred_language', 'uz');
        $this->as($customer)->patchJson(self::URL, ['preferred_language' => 'ru'])
            ->assertOk()
            ->assertJsonPath('data.full_name', 'Aziza Karimova')
            ->assertJsonPath('data.preferred_language', 'ru');

        $fresh = $customer->fresh();

        $this->assertNotNull($fresh);
        $this->assertSame('Aziza Karimova', $fresh->full_name);
        $this->assertSame('ru', $fresh->preferred_language);
    }

    public function test_the_name_bounds_are_one_to_one_hundred_twenty_characters(): void
    {
        $customer = User::factory()->customer()->create(['full_name' => 'Eski Ism']);

        $this->as($customer)->patchJson(self::URL, ['full_name' => str_repeat('я', 120)])->assertOk();

        foreach (['', '   ', null, str_repeat('a', 121), 42] as $name) {
            $this->as($customer)->patchJson(self::URL, ['full_name' => $name])
                ->assertStatus(422)
                ->assertJsonPath('code', 'validation_failed')
                ->assertJsonValidationErrorFor('full_name', 'errors');
        }

        $this->assertSame(str_repeat('я', 120), $customer->fresh()?->full_name);
    }

    public function test_only_uzbek_and_russian_are_languages(): void
    {
        $customer = User::factory()->customer()->create();

        foreach (['en', 'UZ', '', null] as $language) {
            $this->as($customer)->patchJson(self::URL, ['preferred_language' => $language])
                ->assertStatus(422)
                ->assertJsonValidationErrorFor('preferred_language', 'errors');
        }

        $this->assertSame('uz', $customer->fresh()?->preferred_language);
    }

    public function test_the_phone_the_role_and_the_status_are_not_editable_here(): void
    {
        $customer = User::factory()->customer()->create(['phone' => '+998901112233']);

        foreach ([
            ['phone' => '+998909998877'],
            ['role' => 'admin'],
            ['status' => 'blocked'],
            ['full_name' => 'Ism', 'must_change_password' => true],
        ] as $body) {
            $this->as($customer)->patchJson(self::URL, $body)
                ->assertStatus(422)
                ->assertJsonValidationErrorFor((string) array_key_last($body), 'errors');
        }

        $fresh = $customer->fresh();

        $this->assertNotNull($fresh);
        $this->assertSame('+998901112233', $fresh->phone);
        $this->assertSame(Role::Customer, $fresh->role);
        $this->assertNotSame('Ism', $fresh->full_name);
    }

    public function test_an_empty_update_is_refused(): void
    {
        $this->as(User::factory()->customer()->create())->patchJson(self::URL, [])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('body', 'errors');
    }

    public function test_staff_have_no_customer_profile(): void
    {
        foreach ([Role::Admin, Role::Operator, Role::Manager, Role::Shopper, Role::Courier] as $role) {
            $staff = User::factory()->role($role)->create(['full_name' => 'Xodim']);

            $this->as($staff)->getJson(self::URL)->assertStatus(403)->assertJsonPath('code', 'forbidden');
            $this->as($staff)->patchJson(self::URL, ['full_name' => 'Boshqa'])
                ->assertStatus(403)
                ->assertJsonPath('code', 'forbidden');
            $this->assertSame('Xodim', $staff->fresh()?->full_name);
        }
    }

    public function test_without_a_token_the_answer_is_authentication_required(): void
    {
        $this->getJson(self::URL)->assertStatus(401)->assertJsonPath('code', 'authentication_required');
        $this->patchJson(self::URL, ['full_name' => 'X'])->assertStatus(401);
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
