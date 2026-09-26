<?php

declare(strict_types=1);

namespace Tests\Feature\Catalog;

use App\Models\Category;
use App\Models\Enums\Role;
use App\Models\Product;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * The Customer catalog (`docs/09` section 14, `BR-CAT-003`, `BR-CAT-005`,
 * `BR-PRICE-001`, `DL-17` (4)).
 */
final class CustomerCatalogApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_only_active_unarchived_categories_are_listed_in_order(): void
    {
        Category::factory()->create(['name_uz' => 'Mevalar', 'sort_order' => 2]);
        Category::factory()->create(['name_uz' => 'Sabzavotlar', 'sort_order' => 1]);
        Category::factory()->create(['name_uz' => 'Yashirin', 'is_active' => false]);
        Category::factory()->archived()->create(['name_uz' => 'Eski']);

        $response = $this->asCustomer()->getJson('/api/v1/catalog/categories')->assertOk();

        $response->assertJsonPath('data.*.name_uz', ['Sabzavotlar', 'Mevalar'])
            ->assertJsonPath('meta.pagination.total', 2);
        $this->assertSame(
            ['id', 'name_uz', 'name_ru', 'description_uz', 'description_ru', 'sort_order'],
            array_keys($response->json('data.0'))
        );
    }

    public function test_a_product_shows_the_customer_price_and_never_the_market_price(): void
    {
        DB::table('business_settings')->where('id', 1)->update(['markup_percent' => '15.00']);
        $product = Product::factory()->fixed()->create(['market_price_uzs' => 16_000]);

        $data = $this->asCustomer()->getJson('/api/v1/catalog/products/'.$product->id)->assertOk()->json('data');

        $this->assertSame([
            'id', 'category_id', 'name_uz', 'name_ru', 'description_uz', 'description_ru',
            'unit_code', 'price_mode', 'customer_unit_price_uzs', 'image_url', 'is_active',
        ], array_keys($data));
        $this->assertSame(18_400, $data['customer_unit_price_uzs']);
        $this->assertSame('fixed', $data['price_mode']);
        $this->assertNull($data['image_url']);
        $this->assertArrayNotHasKey('market_price_uzs', $data);
    }

    public function test_the_price_follows_a_markup_change_at_once(): void
    {
        $product = Product::factory()->create(['market_price_uzs' => 10_000]);
        $url = '/api/v1/catalog/products/'.$product->id;

        $this->asCustomer()->getJson($url)->assertJsonPath('data.customer_unit_price_uzs', 10_000);
        DB::table('business_settings')->where('id', 1)->update(['markup_percent' => '20.00']);
        $this->asCustomer()->getJson($url)->assertJsonPath('data.customer_unit_price_uzs', 12_000);
    }

    public function test_hidden_archived_and_orphaned_products_do_not_exist_for_the_customer(): void
    {
        $visible = Product::factory()->create(['name_uz' => 'Ko\'rinadi']);
        $hidden = Product::factory()->create(['is_active' => false]);
        $archived = Product::factory()->archived()->create();
        $inHiddenCategory = Product::factory()->create([
            'category_id' => Category::factory()->create(['is_active' => false])->id,
        ]);
        $inArchivedCategory = Product::factory()->create([
            'category_id' => Category::factory()->archived()->create()->id,
        ]);

        $this->asCustomer()->getJson('/api/v1/catalog/products')
            ->assertOk()
            ->assertJsonPath('data.*.id', [$visible->id]);

        foreach ([$hidden, $archived, $inHiddenCategory, $inArchivedCategory] as $product) {
            $this->asCustomer()->getJson('/api/v1/catalog/products/'.$product->id)
                ->assertStatus(404)
                ->assertJsonPath('code', 'resource_not_found');
        }
        $this->asCustomer()->getJson('/api/v1/catalog/products/'.Str::uuid())->assertStatus(404);
    }

    public function test_search_and_the_category_filter_narrow_the_list(): void
    {
        $vegetables = Category::factory()->create();
        Product::factory()->create(['category_id' => $vegetables->id, 'name_uz' => 'Pomidor', 'name_ru' => 'Помидор']);
        Product::factory()->create(['category_id' => $vegetables->id, 'name_uz' => 'Bodring', 'name_ru' => 'Огурец']);
        Product::factory()->create(['name_uz' => 'Asal', 'name_ru' => 'Мёд']);

        $this->asCustomer()->getJson('/api/v1/catalog/products?search='.urlencode('помидор'))
            ->assertJsonPath('data.*.name_uz', ['Pomidor']);
        $this->asCustomer()->getJson('/api/v1/catalog/products?search='.urlencode('мед'))
            ->assertJsonPath('data.*.name_uz', ['Asal']);
        $this->asCustomer()->getJson('/api/v1/catalog/products?category_id='.$vegetables->id)
            ->assertJsonPath('meta.pagination.total', 2);
        $this->asCustomer()->getJson('/api/v1/catalog/products?per_page=1&page=2&category_id='.$vegetables->id)
            ->assertJsonPath('meta.pagination', ['page' => 2, 'per_page' => 1, 'total' => 2, 'last_page' => 2]);
        $this->asCustomer()->getJson('/api/v1/catalog/products?category_id=nope')->assertStatus(422);
    }

    public function test_a_staff_session_is_refused_and_no_session_is_unauthenticated(): void
    {
        $product = Product::factory()->create();

        foreach ([Role::Shopper, Role::Courier, Role::Operator, Role::Admin, Role::Manager] as $role) {
            $token = User::factory()->role($role)->create()->createToken('t')->plainTextToken;

            foreach (['/api/v1/catalog/categories', '/api/v1/catalog/products', '/api/v1/catalog/products/'.$product->id] as $url) {
                $this->withToken($token)->getJson($url)->assertStatus(403)->assertJsonPath('code', 'forbidden');
            }
        }

        $this->withoutToken()->getJson('/api/v1/catalog/products')
            ->assertStatus(401)
            ->assertJsonPath('code', 'authentication_required');
    }

    private function asCustomer(): self
    {
        return $this->withToken(User::factory()->customer()->create()->createToken('t')->plainTextToken);
    }
}
