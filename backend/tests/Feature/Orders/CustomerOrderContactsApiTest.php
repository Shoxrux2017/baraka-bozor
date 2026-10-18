<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\BusinessSettings;
use App\Models\Order;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

/**
 * Who the Customer may call: the Courier only while the order is on the way,
 * and the support phone of the business settings (`docs/09` section 20,
 * `DL-91` (2)).
 */
final class CustomerOrderContactsApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_the_courier_is_shown_only_while_on_the_way(): void
    {
        $customer = User::factory()->customer()->create();
        $assigned = $this->named(Order::factory()->deliveryAssigned()->create(['customer_id' => $customer->id]), phone: '+998901112200');
        $onTheWay = $this->named(Order::factory()->onTheWay()->create(['customer_id' => $customer->id]));
        $completed = $this->named(Order::factory()->completed()->create(['customer_id' => $customer->id]), phone: '+998901112244');

        $courier = ['first_name' => 'Азиз', 'phone' => '+998901112233'];

        $this->as($customer)->getJson("/api/v1/customer/orders/{$assigned->id}")->assertOk()->assertJsonPath('data.courier', null);
        $this->as($customer)->getJson("/api/v1/customer/orders/{$onTheWay->id}")->assertOk()->assertJsonPath('data.courier', $courier);
        $this->as($customer)->getJson("/api/v1/customer/orders/{$completed->id}")->assertOk()->assertJsonPath('data.courier', null);

        $rows = collect($this->as($customer)->getJson('/api/v1/customer/orders')->assertOk()->json('data'))->keyBy('id');
        $this->assertNull($rows[$assigned->id]['courier_phone']);
        $this->assertSame('+998901112233', $rows[$onTheWay->id]['courier_phone']);
        $this->assertNull($rows[$completed->id]['courier_phone']);
    }

    public function test_a_courier_without_a_name_is_shown_by_phone(): void
    {
        $order = Order::factory()->onTheWay()->create();
        $this->named($order, null);

        $this->as($order->customer)->getJson("/api/v1/customer/orders/{$order->id}")
            ->assertOk()
            ->assertJsonPath('data.courier', ['first_name' => null, 'phone' => '+998901112233']);
    }

    public function test_support_phone_follows_the_setting(): void
    {
        $order = Order::factory()->create();
        $url = "/api/v1/customer/orders/{$order->id}";

        $this->as($order->customer)->getJson($url)->assertOk()->assertJsonPath('data.support_phone', null);

        DB::table('business_settings')->where('id', BusinessSettings::SINGLETON_ID)->update(['support_phone' => '+998712000000']);

        $this->as($order->customer)->getJson($url)->assertOk()->assertJsonPath('data.support_phone', '+998712000000');

        $cancelled = Order::factory()->cancelled()->create();
        $this->as($cancelled->customer)->getJson("/api/v1/customer/orders/{$cancelled->id}")
            ->assertOk()
            ->assertJsonPath('data.support_phone', '+998712000000');
    }

    public function test_another_customers_order_reveals_no_courier(): void
    {
        $order = $this->named(Order::factory()->onTheWay()->create());
        $other = User::factory()->customer()->create();

        $this->as($other)->getJson("/api/v1/customer/orders/{$order->id}")
            ->assertNotFound()
            ->assertJsonPath('code', 'resource_not_found');
    }

    /**
     * Gives the order's Courier a name and a phone; staff phones are unique.
     */
    private function named(Order $order, ?string $fullName = 'Азиз Каримов', string $phone = '+998901112233'): Order
    {
        $assignment = $order->courierAssignments()->firstOrFail();

        User::query()->whereKey($assignment->courier_id)->update(['full_name' => $fullName, 'phone' => $phone]);

        return $order;
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
