<?php

declare(strict_types=1);

namespace Tests\Feature\Http;

use App\Models\Category;
use App\Models\CustomerAddress;
use App\Models\Enums\Role;
use App\Models\Product;
use App\Models\PushDevice;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * `docs/09` section 4, `DL-31`: an action that takes no body refuses any
 * field sent to it, and changes nothing.
 */
final class EmptyBodyActionsTest extends TestCase
{
    use RefreshDatabase;

    public function test_every_bodyless_admin_action_refuses_a_field(): void
    {
        $admin = User::factory()->role(Role::Admin)->create();
        $category = Category::factory()->create();
        $product = Product::factory()->create();
        $staff = User::factory()->role(Role::Shopper)->create();
        $token = $admin->createToken('t')->plainTextToken;

        foreach ([
            ['POST', '/api/v1/admin/categories/'.$category->id.'/archive'],
            ['POST', '/api/v1/admin/categories/'.$category->id.'/restore'],
            ['POST', '/api/v1/admin/products/'.$product->id.'/archive'],
            ['POST', '/api/v1/admin/products/'.$product->id.'/restore'],
            ['DELETE', '/api/v1/admin/products/'.$product->id.'/image'],
            ['POST', '/api/v1/admin/staff/'.$staff->id.'/block'],
            ['POST', '/api/v1/admin/staff/'.$staff->id.'/activate'],
            ['POST', '/api/v1/admin/staff/'.$staff->id.'/reset-password'],
        ] as [$method, $url]) {
            $this->withToken($token)->json($method, $url, ['reason' => 'x'])
                ->assertStatus(422)
                ->assertJsonPath('code', 'validation_failed')
                ->assertJsonValidationErrorFor('reason', 'errors');
        }

        $this->assertNull($category->fresh()?->archived_at);
        $this->assertNull($product->fresh()?->archived_at);
        $this->assertTrue($staff->fresh()?->status->value === 'active');
    }

    public function test_the_bodyless_actions_still_work_without_a_body(): void
    {
        $admin = User::factory()->role(Role::Admin)->create();
        $category = Category::factory()->create();

        $this->withToken($admin->createToken('t')->plainTextToken)
            ->postJson('/api/v1/admin/categories/'.$category->id.'/archive')
            ->assertOk();

        $this->assertNotNull($category->fresh()?->archived_at);
    }

    public function test_a_customer_delete_and_a_logout_refuse_a_field(): void
    {
        $customer = User::factory()->customer()->create();
        $address = CustomerAddress::factory()->create(['customer_id' => $customer->id]);
        $device = PushDevice::factory()->create(['user_id' => $customer->id]);
        $token = $customer->createToken('t')->plainTextToken;

        $this->withToken($token)->deleteJson('/api/v1/customer/addresses/'.$address->id, ['is_active' => false])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('is_active', 'errors');
        $this->withToken($token)->deleteJson('/api/v1/push-devices/'.$device->id, ['token' => 'x'])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('token', 'errors');
        $this->withToken($token)->postJson('/api/v1/auth/logout', ['everywhere' => true])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('everywhere', 'errors');

        $this->assertTrue($address->fresh()?->is_active);
        $this->assertNull($device->fresh()?->revoked_at);
        $this->withToken($token)->getJson('/api/v1/auth/me')->assertOk();
    }
}
