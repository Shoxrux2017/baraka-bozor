<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\ProductImage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

/**
 * The Customer's order list: the current and past tabs, the address and the
 * picture of a row, the picture of a detail line (`docs/09` section 20,
 * `DL-90`, `DL-91` (1)).
 */
final class CustomerOrdersListApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_state_current_and_past_split_the_list(): void
    {
        $customer = User::factory()->customer()->create();
        $new = Order::factory()->create(['customer_id' => $customer->id, 'created_at' => now()->subMinutes(4)]);
        $onTheWay = Order::factory()->onTheWay()->create(['customer_id' => $customer->id, 'created_at' => now()->subMinutes(3)]);
        $completed = Order::factory()->completed()->create(['customer_id' => $customer->id, 'created_at' => now()->subMinutes(2)]);
        $cancelled = Order::factory()->cancelled()->create(['customer_id' => $customer->id, 'created_at' => now()->subMinute()]);

        $this->assertSame(
            [$onTheWay->id, $new->id],
            array_column($this->as($customer)->getJson('/api/v1/customer/orders?state=current')->assertOk()->json('data'), 'id'),
        );
        $this->assertSame(
            [$cancelled->id, $completed->id],
            array_column($this->as($customer)->getJson('/api/v1/customer/orders?state=past')->assertOk()->json('data'), 'id'),
        );
        $this->assertCount(4, $this->as($customer)->getJson('/api/v1/customer/orders')->assertOk()->json('data'));

        $this->as($customer)->getJson('/api/v1/customer/orders?state=old')
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('state', 'errors');
    }

    public function test_a_row_carries_the_address_street_and_house(): void
    {
        $order = Order::factory()->create();

        $row = $this->as($order->customer)->getJson('/api/v1/customer/orders')->assertOk()->json('data.0');

        $this->assertSame(['street' => $order->street_snapshot, 'house' => $order->house_snapshot], $row['address']);
    }

    public function test_a_row_pictures_the_earliest_line_with_a_picture(): void
    {
        $order = Order::factory()->create();
        $this->line($order, null, now()->subMinutes(3));
        $this->line($order, 'products/b.webp', now()->subMinutes(2));
        $this->line($order, 'products/c.webp', now()->subMinute());
        $bare = Order::factory()->create(['customer_id' => $order->customer_id, 'created_at' => now()->subHour()]);
        $this->line($bare, null, now());

        $rows = $this->as($order->customer)->getJson('/api/v1/customer/orders')->assertOk()->json('data');
        $byId = array_column($rows, null, 'id');

        $this->assertStringEndsWith('products/b.webp', $byId[$order->id]['image_url']);
        $this->assertNull($byId[$bare->id]['image_url']);
    }

    public function test_detail_lines_carry_their_product_picture(): void
    {
        $order = Order::factory()->create();
        $this->line($order, 'products/with.webp', now()->subMinute());
        $this->line($order, null, now());

        $items = $this->as($order->customer)->getJson("/api/v1/customer/orders/{$order->id}")->assertOk()->json('data.items');

        $this->assertStringEndsWith('products/with.webp', $items[0]['image_url']);
        $this->assertNull($items[1]['image_url']);
    }

    public function test_another_customers_orders_are_not_listed(): void
    {
        $mine = Order::factory()->create();
        $theirs = Order::factory()->create();
        $theirsDone = Order::factory()->completed()->create();

        foreach (['current', 'past'] as $state) {
            $ids = array_column($this->as($mine->customer)->getJson("/api/v1/customer/orders?state={$state}")->assertOk()->json('data'), 'id');
            $this->assertNotContains($theirs->id, $ids);
            $this->assertNotContains($theirsDone->id, $ids);
        }
    }

    private function line(Order $order, ?string $key, \DateTimeInterface $at): OrderItem
    {
        $product = Product::factory()->create();

        if ($key !== null) {
            ProductImage::factory()->create(['product_id' => $product->id, 'storage_key' => $key]);
        }

        return OrderItem::factory()->create(['order_id' => $order->id, 'product_id' => $product->id, 'created_at' => $at]);
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
