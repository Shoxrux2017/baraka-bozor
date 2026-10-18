<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Enums\ItemRemovedReason;
use App\Models\Enums\Role;
use App\Models\Enums\SubstitutionPolicy;
use App\Models\Enums\UnitCode;
use App\Models\IdempotencyKey;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * `POST /customer/orders/{order}/reorder`, `docs/09` section 26,
 * `BR-HIST-005`, `DL-91` item 3.
 */
final class ReorderApiTest extends TestCase
{
    use RefreshDatabase;

    private User $customer;

    private Cart $cart;

    private Order $order;

    protected function setUp(): void
    {
        parent::setUp();

        $this->customer = User::factory()->customer()->create();
        $this->cart = Cart::factory()->create(['customer_id' => $this->customer->id]);
        $this->order = Order::factory()->completed()->create(['customer_id' => $this->customer->id]);
    }

    public function test_reorder_adds_missing_lines_and_reports_the_rest(): void
    {
        $tomato = Product::factory()->create(['name_uz' => 'Pomidor', 'name_ru' => 'Помидор']);
        $bread = Product::factory()->unit(UnitCode::Piece)->create();
        $apple = Product::factory()->create();
        $cucumber = Product::factory()->create();

        $this->line($tomato, '2.000', 1, ['customer_note_snapshot' => 'твёрдые', 'substitution_policy_snapshot' => SubstitutionPolicy::ContactBefore]);
        $this->line($bread, '3.000', 2);
        $this->line($apple, '1.000', 3);
        $this->line($cucumber, '1.000', 4, [], ItemRemovedReason::CustomerRemoved);
        CartItem::factory()->create(['cart_id' => $this->cart->id, 'product_id' => $bread->id, 'quantity' => '1']);
        Product::query()->whereKey($apple->id)->update(['is_active' => false, 'archived_at' => now()]);

        $data = $this->reorder()->assertOk()->json('data');

        $this->assertSame([['product_id' => $tomato->id, 'name_uz' => $tomato->name_uz, 'name_ru' => 'Помидор', 'quantity' => '2.000']], $data['added_items']);
        $this->assertSame([$bread->id], array_column($data['skipped_existing_items'], 'product_id'));
        $this->assertSame([$apple->id], array_column($data['unavailable_items'], 'product_id'));
        $this->assertSame([], $data['cart_full_items']);
        $this->assertNotContains($cucumber->id, array_merge(...array_map(
            static fn (array $list): array => array_column($list, 'product_id'),
            array_values($data),
        )));

        $added = CartItem::query()->where('cart_id', $this->cart->id)->where('product_id', $tomato->id)->sole();
        $this->assertSame('2.000', $added->quantity);
        $this->assertSame('твёрдые', $added->customer_note);
        $this->assertSame(SubstitutionPolicy::ContactBefore, $added->substitution_policy);
        $this->assertEquals(1, CartItem::query()->where('product_id', $bread->id)->sole()->quantity);
        $this->assertSame(1, Order::query()->count(), 'A reorder never creates an order.');
    }

    public function test_the_whole_unit_quantity_is_a_whole_number(): void
    {
        $bread = Product::factory()->unit(UnitCode::Piece)->create();
        $this->line($bread, '3.000', 1);

        $this->reorder()->assertOk()->assertJsonPath('data.added_items.0.quantity', '3');
    }

    public function test_a_product_whose_unit_changed_is_unavailable(): void
    {
        $product = Product::factory()->create();
        $this->line($product, '2.000', 1);
        Product::query()->whereKey($product->id)->update(['unit_code' => UnitCode::Piece->value]);

        $this->reorder()->assertOk()
            ->assertJsonPath('data.added_items', [])
            ->assertJsonPath('data.unavailable_items.0.product_id', $product->id);
        $this->assertSame(0, CartItem::query()->count());
    }

    public function test_a_full_cart_reports_the_rest(): void
    {
        foreach (Product::factory()->count(99)->create() as $product) {
            CartItem::factory()->create(['cart_id' => $this->cart->id, 'product_id' => $product->id]);
        }
        $first = Product::factory()->create();
        $second = Product::factory()->create();
        $third = Product::factory()->create();
        $this->line($first, '1.000', 1);
        $this->line($second, '1.000', 2);
        $this->line($third, '1.000', 3);

        $data = $this->reorder()->assertOk()->json('data');

        $this->assertSame([$first->id], array_column($data['added_items'], 'product_id'));
        $this->assertSame([$second->id, $third->id], array_column($data['cart_full_items'], 'product_id'));
        $this->assertSame(100, CartItem::query()->where('cart_id', $this->cart->id)->count());
    }

    public function test_a_replay_answers_the_first_answer(): void
    {
        $tomato = Product::factory()->create();
        $this->line($tomato, '2.000', 1);
        $key = (string) Str::uuid();

        $first = $this->reorder(null, $key)->assertOk()->json();
        Product::query()->whereKey($tomato->id)->update(['is_active' => false, 'archived_at' => now()]);
        CartItem::query()->delete();

        $this->reorder(null, $key)->assertOk()->assertExactJson($first);
        $this->assertSame(0, CartItem::query()->count());
    }

    public function test_a_second_reorder_with_a_new_key_adds_nothing(): void
    {
        $tomato = Product::factory()->create();
        $this->line($tomato, '2.000', 1);

        $this->reorder()->assertOk()->assertJsonPath('data.added_items.0.product_id', $tomato->id);
        $this->reorder()->assertOk()
            ->assertJsonPath('data.added_items', [])
            ->assertJsonPath('data.skipped_existing_items.0.product_id', $tomato->id);
        $this->assertSame(1, CartItem::query()->count());
    }

    public function test_lines_removed_for_other_reasons_are_reordered(): void
    {
        $product = Product::factory()->create();
        $this->line($product, '1.000', 1, [], ItemRemovedReason::Unavailable);

        $this->reorder()->assertOk()->assertJsonPath('data.added_items.0.product_id', $product->id);
    }

    public function test_reorder_needs_a_key_and_an_own_order(): void
    {
        $this->asCustomer()->postJson($this->url())->assertStatus(400)->assertJsonPath('code', 'idempotency_key_required');

        $other = User::factory()->customer()->create();
        $this->withToken($other->createToken('t')->plainTextToken)
            ->postJson($this->url(), [], ['Idempotency-Key' => (string) Str::uuid()])
            ->assertStatus(404)
            ->assertJsonPath('code', 'resource_not_found');

        $this->reorder(['note' => 'x'])->assertStatus(422);
        $this->assertSame(0, IdempotencyKey::query()->where('actor_user_id', $this->customer->id)->count());

        $shopper = User::factory()->role(Role::Shopper)->create();
        $this->withToken($shopper->createToken('t')->plainTextToken)
            ->postJson($this->url(), [], ['Idempotency-Key' => (string) Str::uuid()])
            ->assertStatus(403);
    }

    /**
     * @param  array<string, mixed>  $attributes
     */
    private function line(Product $product, string $quantity, int $position, array $attributes = [], ?ItemRemovedReason $removed = null): OrderItem
    {
        $factory = OrderItem::factory()->for($this->order)->for($product);
        if ($removed !== null) {
            $factory = $factory->removed($removed);
        }

        return $factory->create(['ordered_quantity' => $quantity, 'created_at' => now()->addSeconds($position)] + $attributes);
    }

    /**
     * @param  array<string, mixed>|null  $body
     */
    private function reorder(?array $body = null, ?string $key = null): TestResponse
    {
        return $this->asCustomer()->postJson($this->url(), $body ?? [], ['Idempotency-Key' => $key ?? (string) Str::uuid()]);
    }

    private function url(): string
    {
        return '/api/v1/customer/orders/'.$this->order->id.'/reorder';
    }

    private function asCustomer(): self
    {
        return $this->withToken($this->customer->createToken('t')->plainTextToken);
    }
}
