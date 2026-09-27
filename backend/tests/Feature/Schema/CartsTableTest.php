<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use App\Models\Cart;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\Database\AssertsDatabaseRejections;
use Tests\Support\Database\ReadsPostgresCatalog;
use Tests\TestCase;

/**
 * `carts` and `cart_items`, as `docs/08-database.md` Sections 9 and 10 name
 * them.
 */
final class CartsTableTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function cart(array $overrides = []): array
    {
        return array_merge([
            'id' => (string) Str::uuid(),
            'customer_id' => User::factory()->customer()->create()->id,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ], $overrides);
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function item(array $overrides = []): array
    {
        return array_merge([
            'id' => (string) Str::uuid(),
            'cart_id' => Cart::factory()->create()->id,
            'product_id' => Product::factory()->create()->id,
            'quantity' => '1.500',
            'customer_note' => null,
            'substitution_policy' => 'allow_similar_substitution',
            'created_at' => now(),
            'updated_at' => now(),
        ], $overrides);
    }

    public function test_a_customer_holds_one_active_cart_and_any_number_of_converted_ones(): void
    {
        $customer = User::factory()->customer()->create();
        DB::table('carts')->insert($this->cart(['customer_id' => $customer->id]));
        DB::table('carts')->insert($this->cart(['customer_id' => $customer->id, 'status' => 'converted']));
        DB::table('carts')->insert($this->cart(['customer_id' => $customer->id, 'status' => 'converted']));

        $this->assertRejectedBy(
            'carts',
            'carts_customer_active_unique',
            $this->cart(['customer_id' => $customer->id]),
            'BR-CART-001: at most one active cart per Customer, even for two first accesses at once.'
        );
        $this->assertStringContainsString(
            "WHERE ((status)::text = 'active'::text)",
            $this->indexesOn('carts')['carts_customer_active_unique']
        );
    }

    public function test_a_cart_status_outside_active_and_converted_is_rejected(): void
    {
        $this->assertRejectedBy(
            'carts',
            'carts_status_check',
            $this->cart(['status' => 'abandoned']),
            'DL-3 S-14 dropped the abandoned status.'
        );
    }

    public function test_a_valid_line_is_accepted_with_three_decimals(): void
    {
        DB::table('cart_items')->insert($this->item(['quantity' => '1.250']));

        $this->assertSame('1.250', (string) DB::table('cart_items')->value('quantity'));
    }

    public function test_a_product_appears_once_per_cart(): void
    {
        $line = $this->item();
        DB::table('cart_items')->insert($line);

        $this->assertRejectedBy(
            'cart_items',
            'cart_items_cart_id_product_id_unique',
            $this->item(['cart_id' => $line['cart_id'], 'product_id' => $line['product_id']]),
            'BR-CART-002: a second add is a conflict, not a second line.'
        );
    }

    public function test_a_quantity_that_is_not_positive_and_an_unknown_rule_are_rejected(): void
    {
        $this->assertRejectedBy('cart_items', 'cart_items_quantity_positive_check', $this->item(['quantity' => '0']), 'BR-QTY-001: positive.');
        $this->assertRejectedBy(
            'cart_items',
            'cart_items_substitution_policy_check',
            $this->item(['substitution_policy' => 'substitute_anything']),
            'Three rules only (01 Section 10).'
        );
    }
}
