<?php

declare(strict_types=1);

namespace Tests\Feature\Orders;

use App\Models\BusinessSettings;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Testing\TestResponse;
use Tests\TestCase;

/**
 * What the cart answers about the charges (`docs/09` section 17,
 * `DL-85` item 1): the fee, the delivery, the total and the minimum order,
 * computed the way checkout computes them. A 15 % markup, so a market price of
 * 16 000 is a customer price of 18 400.
 */
final class CartChargesApiTest extends TestCase
{
    use RefreshDatabase;

    private const CART = '/api/v1/customer/cart';

    private const ITEMS = '/api/v1/customer/cart/items';

    private const KEYS = [
        'service_fee_uzs', 'service_fee_kind', 'delivery_fee_uzs',
        'estimated_total_uzs', 'minimum_order_uzs', 'minimum_order_shortfall_uzs',
    ];

    private User $customer;

    private Product $tomatoes;

    protected function setUp(): void
    {
        parent::setUp();

        $this->settings(['markup_percent' => '15.00']);
        $this->customer = User::factory()->customer()->create();
        $this->tomatoes = Product::factory()->create(['market_price_uzs' => 16000]);
    }

    public function test_the_cart_answers_what_checkout_would_charge(): void
    {
        $this->settings([
            'service_fee_mode' => 'fixed', 'service_fee_fixed_uzs' => 3000,
            'delivery_fee_uzs' => 12000, 'minimum_order_uzs' => 50000,
        ]);
        $this->add($this->tomatoes, '1.5')->assertCreated();

        $data = $this->asCustomer()->getJson(self::CART)->assertOk()->json('data');

        $this->assertSame(27600, $data['estimated_subtotal_uzs']);
        $this->assertSame(3000, $data['service_fee_uzs']);
        $this->assertSame('final', $data['service_fee_kind']);
        $this->assertSame(12000, $data['delivery_fee_uzs']);
        $this->assertSame(42600, $data['estimated_total_uzs']);
        $this->assertSame(50000, $data['minimum_order_uzs']);
        $this->assertSame(22400, $data['minimum_order_shortfall_uzs']);
    }

    public function test_a_percentage_fee_of_an_estimate_is_an_estimate(): void
    {
        $this->settings([
            'service_fee_mode' => 'percentage', 'service_fee_percent' => '5.00',
            'delivery_fee_uzs' => 12000, 'minimum_order_uzs' => 50000,
        ]);
        $this->add($this->tomatoes, '1.5')->assertCreated();

        $data = $this->asCustomer()->getJson(self::CART)->assertOk()->json('data');

        $this->assertSame(1380, $data['service_fee_uzs']);
        $this->assertSame('estimate', $data['service_fee_kind']);
        $this->assertSame(40980, $data['estimated_total_uzs']);
    }

    public function test_the_shortfall_is_zero_once_the_minimum_is_reached(): void
    {
        $this->settings([
            'service_fee_mode' => 'fixed', 'service_fee_fixed_uzs' => 3000,
            'delivery_fee_uzs' => 12000, 'minimum_order_uzs' => 20000,
        ]);
        $this->add($this->tomatoes, '1.5')->assertCreated();

        $data = $this->asCustomer()->getJson(self::CART)->assertOk()->json('data');

        $this->assertSame(20000, $data['minimum_order_uzs']);
        $this->assertSame(0, $data['minimum_order_shortfall_uzs']);
    }

    public function test_a_line_no_longer_sold_is_outside_the_charges(): void
    {
        $this->settings([
            'service_fee_mode' => 'percentage', 'service_fee_percent' => '10.00',
            'delivery_fee_uzs' => 12000, 'minimum_order_uzs' => 50000,
        ]);
        $second = Product::factory()->create(['market_price_uzs' => 20000]);
        $this->add($this->tomatoes, '1.5')->assertCreated();
        $this->add($second, '1')->assertCreated();
        Product::query()->whereKey($second->id)->update(['is_active' => false]);

        $data = $this->asCustomer()->getJson(self::CART)->assertOk()->json('data');

        $this->assertSame(27600, $data['estimated_subtotal_uzs']);
        $this->assertSame(2760, $data['service_fee_uzs']);
        $this->assertSame(42360, $data['estimated_total_uzs']);
    }

    public function test_unset_settings_answer_null(): void
    {
        $this->settings([
            'service_fee_mode' => 'fixed', 'service_fee_fixed_uzs' => 3000,
            'delivery_fee_uzs' => null, 'minimum_order_uzs' => null,
        ]);
        $this->add($this->tomatoes, '1.5')->assertCreated();

        $data = $this->asCustomer()->getJson(self::CART)->assertOk()->json('data');
        $this->assertSame(3000, $data['service_fee_uzs']);
        $this->assertNull($data['delivery_fee_uzs']);
        $this->assertNull($data['estimated_total_uzs']);
        $this->assertNull($data['minimum_order_uzs']);
        $this->assertNull($data['minimum_order_shortfall_uzs']);

        $this->settings(['delivery_fee_uzs' => 12000, 'service_fee_fixed_uzs' => null]);

        $data = $this->asCustomer()->getJson(self::CART)->assertOk()->json('data');
        $this->assertNull($data['service_fee_uzs']);
        $this->assertNull($data['service_fee_kind']);
        $this->assertSame(12000, $data['delivery_fee_uzs']);
        $this->assertNull($data['estimated_total_uzs']);
    }

    public function test_every_cart_answer_carries_the_charges(): void
    {
        $this->settings([
            'service_fee_mode' => 'fixed', 'service_fee_fixed_uzs' => 3000,
            'delivery_fee_uzs' => 12000, 'minimum_order_uzs' => 50000,
        ]);

        $added = $this->add($this->tomatoes, '1')->assertCreated();
        $line = $added->json('data.items.0.id');
        $changed = $this->asCustomer()->patchJson(self::ITEMS.'/'.$line, ['quantity' => '2'])->assertOk();
        $removed = $this->asCustomer()->deleteJson(self::ITEMS.'/'.$line)->assertOk();

        foreach ([$added, $changed, $removed] as $response) {
            foreach (self::KEYS as $key) {
                $this->assertArrayHasKey($key, $response->json('data'), $key);
            }
        }
        $this->assertSame(36800 + 3000 + 12000, $changed->json('data.estimated_total_uzs'));
        $this->assertSame(50000, $removed->json('data.minimum_order_shortfall_uzs'));
    }

    /**
     * @param  array<string, mixed>  $values
     */
    private function settings(array $values): void
    {
        DB::table('business_settings')->where('id', BusinessSettings::SINGLETON_ID)->update($values);
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
