<?php

declare(strict_types=1);

namespace Tests\Feature\Http;

use App\Models\Category;
use App\Models\CustomerAddress;
use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\Product;
use App\Models\ProductImage;
use App\Models\PushDevice;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * `docs/09` section 4, `DL-31`: an action that takes no body refuses any
 * field sent to it, and changes nothing.
 */
final class EmptyBodyActionsTest extends TestCase
{
    use RefreshDatabase;

    public function test_every_bodyless_admin_action_refuses_a_field_and_changes_nothing(): void
    {
        $admin = User::factory()->role(Role::Admin)->create();
        $token = $admin->createToken('t')->plainTextToken;
        // Each action starts from the state it would change.
        $active = Category::factory()->create();
        $archived = Category::factory()->create(['archived_at' => now(), 'is_active' => false]);
        $product = Product::factory()->create();
        $archivedProduct = Product::factory()->create(['archived_at' => now(), 'is_active' => false]);
        $withImage = Product::factory()->create();
        ProductImage::factory()->create(['product_id' => $withImage->id]);
        $shopper = User::factory()->role(Role::Shopper)->create();
        $blocked = User::factory()->role(Role::Courier)->create([
            'status' => UserStatus::Blocked,
            'blocked_at' => now(),
        ]);
        $shopper->createToken('device');
        $hash = $shopper->password;

        foreach ([
            ['POST', '/api/v1/admin/categories/'.$active->id.'/archive'],
            ['POST', '/api/v1/admin/categories/'.$archived->id.'/restore'],
            ['POST', '/api/v1/admin/products/'.$product->id.'/archive'],
            ['POST', '/api/v1/admin/products/'.$archivedProduct->id.'/restore'],
            ['DELETE', '/api/v1/admin/products/'.$withImage->id.'/image'],
            ['POST', '/api/v1/admin/staff/'.$shopper->id.'/block'],
            ['POST', '/api/v1/admin/staff/'.$blocked->id.'/activate'],
            ['POST', '/api/v1/admin/staff/'.$shopper->id.'/reset-password'],
        ] as [$method, $url]) {
            $this->withToken($token)->json($method, $url, ['reason' => 'x'])
                ->assertStatus(422)
                ->assertJsonPath('code', 'validation_failed')
                ->assertJsonValidationErrorFor('reason', 'errors');
        }

        $this->assertNull($active->fresh()?->archived_at);
        $this->assertNotNull($archived->fresh()?->archived_at);
        $this->assertNull($product->fresh()?->archived_at);
        $this->assertNotNull($archivedProduct->fresh()?->archived_at);
        $this->assertSame(1, ProductImage::query()->where('product_id', $withImage->id)->count());
        $this->assertSame(UserStatus::Blocked, $blocked->fresh()?->status);
        $fresh = $shopper->fresh();
        $this->assertNotNull($fresh);
        $this->assertSame(UserStatus::Active, $fresh->status);
        $this->assertSame($hash, $fresh->password);
        $this->assertFalse($fresh->must_change_password);
        $this->assertSame(1, $fresh->tokens()->count());
    }

    public function test_a_form_field_or_a_file_is_refused_like_a_json_field(): void
    {
        $admin = User::factory()->role(Role::Admin)->create();
        $token = $admin->createToken('t')->plainTextToken;
        $category = Category::factory()->create();
        $product = Product::factory()->create();
        ProductImage::factory()->create(['product_id' => $product->id]);

        $this->withToken($token)
            ->post('/api/v1/admin/categories/'.$category->id.'/archive', ['reason' => 'x'], ['Accept' => 'application/json'])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('reason', 'errors');
        $this->withToken($token)
            ->call('DELETE', '/api/v1/admin/products/'.$product->id.'/image', [], [], [
                'image' => UploadedFile::fake()->create('a.png', 1, 'image/png'),
            ], ['HTTP_ACCEPT' => 'application/json', 'HTTP_AUTHORIZATION' => 'Bearer '.$token])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('image', 'errors');

        $this->assertNull($category->fresh()?->archived_at);
        $this->assertSame(1, ProductImage::query()->where('product_id', $product->id)->count());
    }

    public function test_the_refusal_comes_in_the_order_that_reveals_nothing(): void
    {
        $admin = User::factory()->role(Role::Admin)->create();
        $customer = User::factory()->customer()->create();
        $missing = (string) Str::uuid();

        $this->postJson('/api/v1/admin/staff/'.$missing.'/block', ['reason' => 'x'])
            ->assertStatus(401);
        $this->withToken($customer->createToken('t')->plainTextToken)
            ->postJson('/api/v1/admin/staff/'.$missing.'/block', ['reason' => 'x'])
            ->assertStatus(403);
        // A missing record with a body is refused on the body, as an existing
        // one is: the answer does not say whether the record exists.
        $this->withToken($admin->createToken('t')->plainTextToken)
            ->postJson('/api/v1/admin/staff/'.$missing.'/block', ['reason' => 'x'])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('reason', 'errors');
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
