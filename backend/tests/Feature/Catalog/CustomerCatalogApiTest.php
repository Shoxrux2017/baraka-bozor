<?php

declare(strict_types=1);

namespace Tests\Feature\Catalog;

use App\Models\Category;
use App\Models\CategoryImage;
use App\Models\Enums\Role;
use App\Models\Product;
use App\Models\ProductImage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * The Customer catalog (`docs/09` section 14, `BR-CAT-005`, `BR-PRICE-001`,
 * `DL-17` (4), `DL-22`).
 */
final class CustomerCatalogApiTest extends TestCase
{
    use RefreshDatabase;

    public function test_only_active_unarchived_categories_with_a_visible_product_are_listed_in_order(): void
    {
        Product::factory()->for(Category::factory()->state(['name_uz' => 'Mevalar', 'sort_order' => 2]))->create();
        Product::factory()->for(Category::factory()->state(['name_uz' => 'Sabzavotlar', 'sort_order' => 1]))->create();
        Product::factory()->for(Category::factory()->state(['name_uz' => 'Yashirin', 'is_active' => false]))->create();
        Product::factory()->for(Category::factory()->archived()->state(['name_uz' => 'Eski']))->create();
        Category::factory()->create(['name_uz' => 'Bo\'sh']);
        Product::factory()->for(Category::factory()->state(['name_uz' => 'Yopiq mahsulot']))->create(['is_active' => false]);
        Product::factory()->archived()->for(Category::factory()->state(['name_uz' => 'Arxiv mahsulot']))->create();

        $response = $this->asCustomer()->getJson('/api/v1/catalog/categories')->assertOk();

        $response->assertJsonPath('data.*.name_uz', ['Sabzavotlar', 'Mevalar'])
            ->assertJsonPath('meta.pagination.total', 2);
        $this->assertSame(
            ['id', 'name_uz', 'name_ru', 'description_uz', 'description_ru', 'sort_order', 'image_url'],
            array_keys($response->json('data.0'))
        );
    }

    public function test_a_listed_category_carries_its_picture_url_or_null(): void
    {
        $category = Category::factory()->create();
        Product::factory()->for($category)->create();

        $this->asCustomer()->getJson('/api/v1/catalog/categories')
            ->assertOk()
            ->assertJsonPath('data.0.image_url', null);

        $image = CategoryImage::factory()->create(['category_id' => $category->id]);

        $this->asCustomer()->getJson('/api/v1/catalog/categories')
            ->assertOk()
            ->assertJsonPath('data.0.image_url', Storage::disk('public')->url($image->storage_key));
    }

    public function test_a_product_shows_the_customer_price_and_never_the_market_price(): void
    {
        DB::table('business_settings')->where('id', 1)->update(['markup_percent' => '15.00']);
        $product = Product::factory()->create(['market_price_uzs' => 16_000]);

        $data = $this->asCustomer()->getJson('/api/v1/catalog/products/'.$product->id)->assertOk()->json('data');

        $this->assertSame([
            'id', 'category_id', 'name_uz', 'name_ru', 'description_uz', 'description_ru',
            'unit_code', 'price_mode', 'customer_unit_price_uzs', 'image_url', 'is_active',
        ], array_keys($data));
        $this->assertSame(18_400, $data['customer_unit_price_uzs']);
        $this->assertSame('estimate', $data['price_mode']);
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
            ->assertJsonPath('meta.pagination', ['page' => 2, 'per_page' => 1, 'total' => 2, 'last_page' => 2])
            ->assertJsonPath('data.*.name_uz', ['Pomidor']);
        $this->asCustomer()->getJson('/api/v1/catalog/products?search=POMI')
            ->assertJsonPath('data.*.name_uz', ['Pomidor']);
        $this->asCustomer()->getJson('/api/v1/catalog/products?search=o&category_id='.$vegetables->id)
            ->assertJsonPath('data.*.name_uz', ['Bodring', 'Pomidor']);
        $this->asCustomer()->getJson('/api/v1/catalog/products?search=asal&category_id='.$vegetables->id)
            ->assertJsonPath('meta.pagination.total', 0);
        $this->asCustomer()->getJson('/api/v1/catalog/products?category_id=nope')->assertStatus(422);
    }

    public function test_neither_search_nor_the_category_filter_brings_back_a_hidden_product(): void
    {
        $hiddenCategory = Category::factory()->create(['is_active' => false]);
        $archivedCategory = Category::factory()->archived()->create();
        $visible = Product::factory()->create(['name_uz' => 'Olma qizil', 'name_ru' => 'Яблоко красное']);
        Product::factory()->create(['name_uz' => 'Olma yashirin', 'name_ru' => 'Яблоко скрытое', 'is_active' => false]);
        Product::factory()->archived()->create(['name_uz' => 'Olma eski', 'name_ru' => 'Яблоко старое']);
        Product::factory()->create(['category_id' => $hiddenCategory->id, 'name_uz' => 'Olma bog\'i', 'name_ru' => 'Яблоко садовое']);
        Product::factory()->create(['category_id' => $archivedCategory->id, 'name_uz' => 'Olma quruq', 'name_ru' => 'Яблоко сушёное']);

        foreach (['olma', 'яблоко', 'Olma'] as $term) {
            $this->asCustomer()->getJson('/api/v1/catalog/products?search='.urlencode($term))
                ->assertOk()
                ->assertJsonPath('data.*.id', [$visible->id]);
        }

        foreach ([$hiddenCategory->id, $archivedCategory->id, (string) Str::uuid()] as $categoryId) {
            $this->asCustomer()->getJson('/api/v1/catalog/products?category_id='.$categoryId)
                ->assertOk()
                ->assertJsonPath('data', [])
                ->assertJsonPath('meta.pagination.total', 0);
            $this->asCustomer()->getJson('/api/v1/catalog/products?search=olma&category_id='.$categoryId)
                ->assertOk()
                ->assertJsonPath('data', []);
        }
    }

    public function test_a_product_with_an_image_carries_its_public_url(): void
    {
        $image = ProductImage::factory()->create();
        $url = Storage::disk('public')->url($image->storage_key);

        $this->asCustomer()->getJson('/api/v1/catalog/products/'.$image->product_id)
            ->assertOk()
            ->assertJsonPath('data.image_url', $url);
        $this->asCustomer()->getJson('/api/v1/catalog/products')
            ->assertOk()
            ->assertJsonPath('data.0.image_url', $url);
    }

    public function test_the_pagination_bounds_hold_on_both_lists(): void
    {
        Product::factory()->create();

        foreach (['/api/v1/catalog/categories', '/api/v1/catalog/products'] as $url) {
            foreach (['per_page=0', 'per_page=101', 'page=0', 'page=100001', 'per_page=abc'] as $query) {
                $this->asCustomer()->getJson($url.'?'.$query)
                    ->assertStatus(422)
                    ->assertJsonPath('code', 'validation_failed');
            }

            $this->asCustomer()->getJson($url.'?per_page=100&page=100000')
                ->assertOk()
                ->assertJsonPath('data', []);
        }
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

        foreach (['/api/v1/catalog/categories', '/api/v1/catalog/products', '/api/v1/catalog/products/'.$product->id] as $url) {
            $this->withoutToken()->getJson($url)
                ->assertStatus(401)
                ->assertJsonPath('code', 'authentication_required');
        }
    }

    public function test_featured_lists_only_visible_featured_products(): void
    {
        $featured = Product::factory()->featured()->create(['name_uz' => 'Olma']);
        Product::factory()->create(['name_uz' => 'Nok']);
        Product::factory()->featured()->archived()->create();
        Product::factory()->featured()->create(['is_active' => false]);
        Product::factory()->featured()->create(['category_id' => Category::factory()->archived()->create()->id]);

        $this->asCustomer()->getJson('/api/v1/catalog/products?featured=1')
            ->assertOk()->assertJsonPath('data.*.id', [$featured->id]);
        $this->asCustomer()->getJson('/api/v1/catalog/products?featured=true')
            ->assertJsonPath('data.*.id', [$featured->id]);
        $this->asCustomer()->getJson('/api/v1/catalog/products?featured=0')->assertJsonPath('meta.pagination.total', 2);
        $this->asCustomer()->getJson('/api/v1/catalog/products?featured=false')->assertJsonPath('meta.pagination.total', 2);
        $this->asCustomer()->getJson('/api/v1/catalog/products')->assertJsonPath('meta.pagination.total', 2);
    }

    public function test_the_price_sort_orders_by_price_then_by_the_shops_order(): void
    {
        $this->pricedProducts();

        $this->asCustomer()->getJson('/api/v1/catalog/products?sort=price_asc')
            ->assertJsonPath('data.*.name_uz', ['A5', 'B5', 'C7', 'D9']);
        $this->asCustomer()->getJson('/api/v1/catalog/products?sort=price_desc')
            ->assertJsonPath('data.*.name_uz', ['D9', 'C7', 'A5', 'B5']);
        $this->asCustomer()->getJson('/api/v1/catalog/products?sort=default')
            ->assertJsonPath('data.*.name_uz', ['A5', 'B5', 'D9', 'C7']);
        $this->asCustomer()->getJson('/api/v1/catalog/products')
            ->assertJsonPath('data.*.name_uz', ['A5', 'B5', 'D9', 'C7']);
    }

    public function test_pages_of_the_price_sort_list_every_product_once(): void
    {
        $this->pricedProducts();

        $names = [];
        $prices = [];
        foreach ([1, 2] as $page) {
            $data = $this->asCustomer()->getJson("/api/v1/catalog/products?sort=price_asc&per_page=2&page={$page}")
                ->assertOk()->json('data');
            foreach ($data as $row) {
                $names[] = $row['name_uz'];
                $prices[] = $row['customer_unit_price_uzs'];
            }
        }

        $this->assertSame(['A5', 'B5', 'C7', 'D9'], $names);
        $sorted = $prices;
        sort($sorted);
        $this->assertSame($sorted, $prices);
    }

    public function test_the_sort_composes_with_the_other_filters(): void
    {
        $vegetables = Category::factory()->create();
        Product::factory()->featured()->create(['category_id' => $vegetables->id, 'name_uz' => 'Pomidor', 'market_price_uzs' => 9000]);
        Product::factory()->featured()->create(['category_id' => $vegetables->id, 'name_uz' => 'Piyoz', 'market_price_uzs' => 3000]);
        Product::factory()->create(['category_id' => $vegetables->id, 'name_uz' => 'Pista', 'market_price_uzs' => 1000]);
        Product::factory()->featured()->create(['name_uz' => 'Pech', 'market_price_uzs' => 2000]);

        $this->asCustomer()->getJson('/api/v1/catalog/products?sort=price_asc&featured=1&category_id='.$vegetables->id.'&search=p')
            ->assertJsonPath('data.*.name_uz', ['Piyoz', 'Pomidor']);
        $this->asCustomer()->getJson('/api/v1/catalog/products?sort=price_desc&category_id='.$vegetables->id)
            ->assertJsonPath('data.*.name_uz', ['Pomidor', 'Piyoz', 'Pista']);
        $this->asCustomer()->getJson('/api/v1/catalog/products?sort=price_asc&featured=1')
            ->assertJsonPath('data.*.name_uz', ['Pech', 'Piyoz', 'Pomidor']);
    }

    public function test_an_unknown_sort_or_featured_value_is_refused(): void
    {
        $this->asCustomer()->getJson('/api/v1/catalog/products?sort=cheap')
            ->assertStatus(422)->assertJsonPath('code', 'validation_failed');
        $this->asCustomer()->getJson('/api/v1/catalog/products?featured=yes')
            ->assertStatus(422)->assertJsonPath('code', 'validation_failed');
    }

    private function pricedProducts(): void
    {
        Product::factory()->create(['name_uz' => 'D9', 'market_price_uzs' => 9000, 'sort_order' => 2]);
        Product::factory()->create(['name_uz' => 'B5', 'market_price_uzs' => 5000, 'sort_order' => 1]);
        Product::factory()->create(['name_uz' => 'C7', 'market_price_uzs' => 7000, 'sort_order' => 3]);
        Product::factory()->create(['name_uz' => 'A5', 'market_price_uzs' => 5000, 'sort_order' => 1]);
    }

    private function asCustomer(): self
    {
        return $this->withToken(User::factory()->customer()->create()->createToken('t')->plainTextToken);
    }
}
