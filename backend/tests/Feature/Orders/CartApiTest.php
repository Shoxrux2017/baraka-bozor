<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\BusinessSettings;
use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Category;
use App\Models\Enums\Role;
use App\Models\Enums\UnitCode;
use App\Models\Product;
use App\Models\User;
use App\Modules\Orders\Actions\ChangeCart;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * The Customer's cart, `docs/09` section 17: `BR-CART-001` to `BR-CART-004`,
 * the quantity rules of `BR-QTY-001` with the bounds of `DL-37` (6), and the
 * unavailable products of `DL-37` (20). A 15 % markup throughout, so a market
 * price of 16 000 is a customer price of 18 400.
 */
final class CartApiTest extends TestCase
{
    use RefreshDatabase;

    private const CART = '/api/v1/customer/cart';

    private const ITEMS = '/api/v1/customer/cart/items';

    private User $customer;

    private Product $tomatoes;

    protected function setUp(): void
    {
        parent::setUp();

        DB::table('business_settings')->where('id', BusinessSettings::SINGLETON_ID)->update(['markup_percent' => '15.00']);
        $this->customer = User::factory()->customer()->create();
        $this->tomatoes = Product::factory()->create(['market_price_uzs' => 16000]);
    }

    public function test_the_first_access_creates_one_empty_active_cart(): void
    {
        $first = $this->asCustomer()->getJson(self::CART)->assertOk();
        $again = $this->asCustomer()->getJson(self::CART)->assertOk();

        $this->assertSame(['id', 'items', 'item_count', 'estimated_subtotal_uzs'], array_keys($first->json('data')));
        $this->assertSame([], $first->json('data.items'));
        $this->assertSame(0, $first->json('data.estimated_subtotal_uzs'));
        $this->assertSame($first->json('data.id'), $again->json('data.id'));
        $this->assertSame(1, Cart::query()->where('customer_id', $this->customer->id)->count());
    }

    public function test_a_line_is_added_at_the_current_customer_price_with_the_default_rule(): void
    {
        $response = $this->add($this->tomatoes, '1.5')->assertCreated();

        $line = $response->json('data.items.0');
        $this->assertSame([
            'id', 'product_id', 'name_uz', 'name_ru', 'unit_code', 'price_mode', 'image_url', 'quantity',
            'customer_note', 'substitution_policy', 'is_available', 'customer_unit_price_uzs', 'estimated_line_total_uzs',
        ], array_keys($line));
        $this->assertSame($this->tomatoes->id, $line['product_id']);
        $this->assertSame('1.500', $line['quantity']);
        $this->assertSame(18400, $line['customer_unit_price_uzs']);
        $this->assertSame(27600, $line['estimated_line_total_uzs']);
        $this->assertSame('allow_similar_substitution', $line['substitution_policy']);
        $this->assertTrue($line['is_available']);
        $this->assertSame(27600, $response->json('data.estimated_subtotal_uzs'));
        $this->assertStringNotContainsString('market_price', (string) $response->getContent(), 'BR-PRICE-001.');
    }

    public function test_a_line_estimate_rounds_half_up(): void
    {
        // 18 401 × 1.5 = 27 601.5, half-up to 27 602.
        $odd = Product::factory()->create(['market_price_uzs' => 16001]); // 18 401.15 → 18 401
        $response = $this->add($odd, '1.5')->assertCreated();

        $this->assertSame(18401, $response->json('data.items.0.customer_unit_price_uzs'));
        $this->assertSame(27602, $response->json('data.items.0.estimated_line_total_uzs'));
    }

    public function test_a_whole_unit_takes_a_whole_number_and_a_decimal_unit_three_decimals(): void
    {
        $bread = Product::factory()->unit(UnitCode::Piece)->create();

        $this->add($bread, '2')->assertCreated()->assertJsonPath('data.items.0.quantity', '2');

        foreach (['2.5', '2.0', '0', '10000', '-1', 'two', ''] as $refused) {
            $this->add(Product::factory()->unit(UnitCode::Piece)->create(), $refused)
                ->assertStatus(422)->assertJsonPath('code', 'validation_failed')
                ->assertJsonStructure(['errors' => ['quantity']]);
        }
        foreach (['1.2345', '0.000', '10000', '9999.9999', '1,5'] as $refused) {
            $this->add(Product::factory()->create(), $refused)
                ->assertStatus(422)->assertJsonStructure(['errors' => ['quantity']]);
        }

        $this->add(Product::factory()->create(), '9999.999')->assertCreated();
        $this->add(Product::factory()->unit(UnitCode::Box)->create(), '9999')->assertCreated();
    }

    public function test_a_quantity_sent_as_a_json_number_is_refused(): void
    {
        $this->asCustomer()->postJson(self::ITEMS, ['product_id' => $this->tomatoes->id, 'quantity' => 2])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['quantity']]);

        $line = $this->add($this->tomatoes, '1')->json('data.items.0.id');
        $this->asCustomer()->patchJson(self::ITEMS.'/'.$line, ['quantity' => 2])
            ->assertStatus(422)->assertJsonStructure(['errors' => ['quantity']]);
    }

    public function test_an_undeclared_field_is_refused_and_a_blank_note_is_none(): void
    {
        $this->asCustomer()->postJson(self::ITEMS, [
            'product_id' => $this->tomatoes->id,
            'quantity' => '1',
            'customer_unit_price_uzs' => 1,
        ])->assertStatus(422)->assertJsonPath('code', 'validation_failed');

        $line = $this->asCustomer()->postJson(self::ITEMS, [
            'product_id' => $this->tomatoes->id,
            'quantity' => '1',
            'customer_note' => '   ',
        ])->assertCreated()->assertJsonPath('data.items.0.customer_note', null)->json('data.items.0.id');

        $this->asCustomer()->patchJson(self::ITEMS.'/'.$line, ['customer_note' => '  Pishgan  '])
            ->assertOk()->assertJsonPath('data.items.0.customer_note', 'Pishgan');
        $this->asCustomer()->patchJson(self::ITEMS.'/'.$line, ['customer_note' => ''])
            ->assertOk()->assertJsonPath('data.items.0.customer_note', null);
    }

    public function test_a_product_is_added_once(): void
    {
        $first = $this->add($this->tomatoes, '1')->assertCreated();

        $this->add($this->tomatoes, '2')
            ->assertStatus(409)
            ->assertJsonPath('code', 'cart_item_already_exists')
            ->assertJsonPath('details.cart_item_id', $first->json('data.items.0.id'));
    }

    public function test_the_hundredth_line_is_accepted_and_the_hundred_and_first_refused(): void
    {
        $cart = Cart::factory()->create(['customer_id' => $this->customer->id]);
        $category = Category::factory()->create();
        $products = Product::factory()->count(ChangeCart::MAX_LINES - 1)->create(['category_id' => $category->id]);
        DB::table('cart_items')->insert($products->map(static fn (Product $product): array => [
            'id' => (string) Str::uuid(),
            'cart_id' => $cart->id,
            'product_id' => $product->id,
            'quantity' => '1.000',
            'substitution_policy' => 'allow_similar_substitution',
            'created_at' => now(),
            'updated_at' => now(),
        ])->all());

        $this->add($this->tomatoes, '1')->assertCreated()->assertJsonPath('data.item_count', ChangeCart::MAX_LINES);

        $this->add(Product::factory()->create(), '1')
            ->assertStatus(409)
            ->assertJsonPath('code', 'cart_full')
            ->assertJsonPath('details.max_lines', ChangeCart::MAX_LINES);
    }

    public function test_a_hidden_product_and_an_unknown_one_are_the_same_refusal(): void
    {
        $archived = Product::factory()->archived()->create();
        $inHiddenCategory = Product::factory()->create(['category_id' => Category::factory()->archived()->create()->id]);
        $unknown = (string) Str::uuid();

        $inactive = Product::factory()->create(['is_active' => false]);
        $inInactiveCategory = Product::factory()->create(['category_id' => Category::factory()->create(['is_active' => false])->id]);

        foreach ([$archived->id, $inHiddenCategory->id, $inactive->id, $inInactiveCategory->id, $unknown] as $id) {
            $this->asCustomer()->postJson(self::ITEMS, ['product_id' => $id, 'quantity' => '1'])
                ->assertStatus(409)
                ->assertJsonPath('code', 'product_unavailable')
                ->assertJsonPath('details.product_ids', [$id]);
        }
    }

    public function test_a_line_whose_product_became_unavailable_stays_marked_and_may_only_be_removed(): void
    {
        $bread = Product::factory()->unit(UnitCode::Piece)->create(['market_price_uzs' => 3000]);
        $this->add($bread, '2')->assertCreated();
        $line = $this->add($this->tomatoes, '1')->json('data.items.1.id');
        Product::query()->whereKey($this->tomatoes->id)->update(['is_active' => false]);

        $cart = $this->asCustomer()->getJson(self::CART)->assertOk();
        $this->assertFalse($cart->json('data.items.1.is_available'));
        $this->assertNull($cart->json('data.items.1.customer_unit_price_uzs'));
        $this->assertNull($cart->json('data.items.1.estimated_line_total_uzs'));
        $this->assertSame(6900, $cart->json('data.estimated_subtotal_uzs'), 'Only the available line counts.');

        $this->asCustomer()->patchJson(self::ITEMS.'/'.$line, ['quantity' => '3'])
            ->assertStatus(409)->assertJsonPath('code', 'product_unavailable');
        $this->asCustomer()->patchJson(self::ITEMS.'/'.$line, ['customer_note' => 'Baribir'])
            ->assertStatus(409)->assertJsonPath('code', 'product_unavailable');
        $this->asCustomer()->deleteJson(self::ITEMS.'/'.$line)->assertOk()->assertJsonPath('data.item_count', 1);
    }

    public function test_prices_follow_the_current_markup(): void
    {
        $this->add($this->tomatoes, '1')->assertCreated();
        DB::table('business_settings')->where('id', BusinessSettings::SINGLETON_ID)->update(['markup_percent' => '20.00']);

        $this->asCustomer()->getJson(self::CART)->assertJsonPath('data.items.0.customer_unit_price_uzs', 19200);
    }

    public function test_a_line_changes_its_quantity_note_and_rule(): void
    {
        $line = $this->add($this->tomatoes, '1')->json('data.items.0.id');

        $this->asCustomer()->patchJson(self::ITEMS.'/'.$line, [
            'quantity' => '2.25',
            'customer_note' => 'Qattiqroq bo\'lsin',
            'substitution_policy' => 'contact_before_substitution',
        ])->assertOk()
            ->assertJsonPath('data.items.0.quantity', '2.250')
            ->assertJsonPath('data.items.0.customer_note', 'Qattiqroq bo\'lsin')
            ->assertJsonPath('data.items.0.substitution_policy', 'contact_before_substitution')
            ->assertJsonPath('data.items.0.estimated_line_total_uzs', 41400);

        $this->asCustomer()->patchJson(self::ITEMS.'/'.$line, ['customer_note' => null])
            ->assertOk()->assertJsonPath('data.items.0.customer_note', null);
        $this->asCustomer()->patchJson(self::ITEMS.'/'.$line, [])->assertStatus(422);
        $this->asCustomer()->patchJson(self::ITEMS.'/'.$line, ['product_id' => $this->tomatoes->id])->assertStatus(422);
        $this->asCustomer()->patchJson(self::ITEMS.'/'.$line, ['substitution_policy' => 'anything'])->assertStatus(422);
        $this->asCustomer()->patchJson(self::ITEMS.'/'.$line, ['quantity' => '1.0001'])->assertStatus(422);
    }

    public function test_another_customers_line_is_not_found_and_staff_are_refused(): void
    {
        $line = $this->add($this->tomatoes, '1')->json('data.items.0.id');
        $other = User::factory()->customer()->create();
        $asOther = $this->withToken($other->createToken('t')->plainTextToken);

        $asOther->patchJson(self::ITEMS.'/'.$line, ['quantity' => '2'])->assertStatus(404)->assertJsonPath('code', 'resource_not_found');
        $asOther->deleteJson(self::ITEMS.'/'.$line)->assertStatus(404);
        $this->assertSame(1, CartItem::query()->count());

        $shopper = User::factory()->role(Role::Shopper)->create();
        $this->withToken($shopper->createToken('t')->plainTextToken)->getJson(self::CART)->assertStatus(403);
    }

    public function test_a_removed_line_leaves_the_cart(): void
    {
        $line = $this->add($this->tomatoes, '1')->json('data.items.0.id');

        $this->asCustomer()->deleteJson(self::ITEMS.'/'.$line)
            ->assertOk()
            ->assertJsonPath('data.items', [])
            ->assertJsonPath('data.estimated_subtotal_uzs', 0);
        $this->asCustomer()->deleteJson(self::ITEMS.'/'.$line)->assertStatus(404);
        $this->asCustomer()->deleteJson(self::ITEMS.'/'.(string) Str::uuid(), ['x' => 1])->assertStatus(422);
    }

    private function add(Product $product, string $quantity): TestResponse
    {
        return $this->asCustomer()->postJson(self::ITEMS, ['product_id' => $product->id, 'quantity' => $quantity]);
    }

    private function asCustomer(): self
    {
        return $this->withToken($this->customer->createToken('t')->plainTextToken);
    }
}
