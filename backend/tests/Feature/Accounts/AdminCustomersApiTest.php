<?php

declare(strict_types=1);

namespace Tests\Feature\Accounts;

use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * The Admin finds a Customer by phone and erases the account on request
 * (`docs/09` Sections 66 and 67, `DL-94` item 5).
 */
final class AdminCustomersApiTest extends TestCase
{
    use RefreshDatabase;

    private const PHONE = '+998901234567';

    private User $admin;

    protected function setUp(): void
    {
        parent::setUp();

        $this->admin = User::factory()->role(Role::Admin)->create();
    }

    public function test_an_admin_finds_customers_by_phone(): void
    {
        $blocked = User::factory()->customer()->blocked()->create(['phone' => self::PHONE, 'full_name' => 'Blocked One']);
        $active = User::factory()->customer()->create(['phone' => self::PHONE, 'full_name' => 'Active One']);
        User::factory()->role(Role::Courier)->create(['phone' => self::PHONE]);
        Order::factory()->completed()->create(['customer_id' => $active->id]);
        $unfinished = Order::factory()->create(['customer_id' => $active->id]);

        $data = $this->as($this->admin)->getJson('/api/v1/admin/customers?phone='.urlencode(self::PHONE))
            ->assertOk()->json('data');

        $this->assertSame([$active->id, $blocked->id], array_column($data, 'id'));
        $this->assertSame('active', $data[0]['status']);
        $this->assertSame('Active One', $data[0]['full_name']);
        $this->assertSame(self::PHONE, $data[0]['phone']);
        $this->assertSame(2, $data[0]['order_count']);
        $this->assertSame(
            ['id' => $unfinished->id, 'order_number' => $unfinished->fresh()?->order_number],
            $data[0]['unfinished_order'],
        );
        $this->assertArrayHasKey('created_at', $data[0]);
        $this->assertArrayHasKey('last_login_at', $data[0]);
        $this->assertSame('blocked', $data[1]['status']);
        $this->assertSame(0, $data[1]['order_count']);
        $this->assertNull($data[1]['unfinished_order']);

        $this->as($this->admin)->getJson('/api/v1/admin/customers?phone='.urlencode('+998909999999'))
            ->assertOk()->assertExactJson(['data' => []]);
        $this->as($this->admin)->getJson('/api/v1/admin/customers?phone=12345')->assertStatus(422);
        $this->as($this->admin)->getJson('/api/v1/admin/customers')->assertStatus(422);
    }

    public function test_an_admin_erases_a_customer(): void
    {
        $customer = User::factory()->customer()->create(['phone' => self::PHONE]);
        $token = $customer->createToken('customer')->plainTextToken;
        Order::factory()->completed()->create(['customer_id' => $customer->id]);

        $this->as($this->admin)->postJson('/api/v1/admin/customers/'.$customer->id.'/erase')->assertNoContent();

        $user = User::query()->findOrFail($customer->id);
        $this->assertSame(UserStatus::Deleted, $user->status);
        $this->assertSame($this->admin->id, $user->deleted_by_user_id);
        $this->assertNull($user->phone);

        $this->flushHeaders();
        $this->withToken($token)->getJson('/api/v1/customer/profile')->assertStatus(401);
    }

    public function test_erasure_is_refused_for_staff_deleted_unknown_and_unfinished(): void
    {
        $courier = User::factory()->role(Role::Courier)->create();
        $deleted = User::factory()->customer()->create();
        $this->as($this->admin)->postJson('/api/v1/admin/customers/'.$deleted->id.'/erase')->assertNoContent();
        $busy = User::factory()->customer()->create();
        $order = Order::factory()->onTheWay()->create(['customer_id' => $busy->id]);

        foreach ([$courier->id, $deleted->id, (string) Str::uuid()] as $id) {
            $this->as($this->admin)->postJson('/api/v1/admin/customers/'.$id.'/erase')
                ->assertStatus(404)->assertJsonPath('code', 'resource_not_found');
        }

        $this->as($this->admin)->postJson('/api/v1/admin/customers/'.$busy->id.'/erase')
            ->assertStatus(409)
            ->assertJsonPath('code', 'account_has_unfinished_orders')
            ->assertJsonPath('details.order_id', $order->id)
            ->assertJsonPath('details.order_number', $order->fresh()?->order_number);
        $this->assertSame(UserStatus::Active, User::query()->findOrFail($busy->id)->status);
    }

    public function test_only_admins(): void
    {
        $customer = User::factory()->customer()->create();

        foreach ([Role::Operator, Role::Manager, Role::Customer] as $role) {
            $as = $this->as(User::factory()->role($role)->create());
            $as->getJson('/api/v1/admin/customers?phone='.urlencode(self::PHONE))->assertStatus(403);
            $as->postJson('/api/v1/admin/customers/'.$customer->id.'/erase')->assertStatus(403);
        }
        $this->assertSame(UserStatus::Active, User::query()->findOrFail($customer->id)->status);

        $this->as($this->admin)->postJson('/api/v1/admin/customers/'.$customer->id.'/erase', ['reason' => 'x'])
            ->assertStatus(422);
        $this->assertSame(UserStatus::Active, User::query()->findOrFail($customer->id)->status);
    }

    private function as(User $user): self
    {
        $this->flushHeaders();

        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
