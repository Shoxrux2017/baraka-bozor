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
 * `/api/v1/admin/products` (`docs/09` section 15, `BR-CAT-*`, `BR-PRICE-001`,
 * `DL-17` (3), (10), (14), `DL-18` (2)).
 */
final class AdminProductsApiTest extends TestCase
{
    use RefreshDatabase;

    private const URL = '/api/v1/admin/products';

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function body(array $overrides = []): array
    {
        return array_merge([
            'category_id' => Category::factory()->create()->id,
            'name_uz' => 'Pomidor',
            'name_ru' => 'Помидор',
            'unit_code' => 'kg',
            'price_mode' => 'estimate',
            'market_price_uzs' => 16_000,
        ], $overrides);
    }

    public function test_an_admin_creates_a_product_and_sees_both_prices(): void
    {
        DB::table('business_settings')->where('id', 1)->update(['markup_percent' => '15.00']);
        $admin = User::factory()->role(Role::Admin)->create();

        $response = $this->asAdmin($admin)->postJson(self::URL, $this->body())->assertCreated();

        $response->assertJsonPath('data.market_price_uzs', 16_000)
            ->assertJsonPath('data.customer_unit_price_uzs', 18_400)
            ->assertJsonPath('data.unit_code', 'kg')
            ->assertJsonPath('data.price_mode', 'estimate')
            ->assertJsonPath('data.is_active', true)
            ->assertJsonPath('data.sort_order', 0);

        $this->assertSame($admin->id, Product::query()->findOrFail($response->json('data.id'))->created_by_user_id);
    }

    public function test_the_customer_price_follows_the_current_markup_without_touching_the_product(): void
    {
        $product = Product::factory()->create(['market_price_uzs' => 10_000]);
        $url = self::URL.'/'.$product->id;

        $this->asAdmin()->getJson($url)->assertJsonPath('data.customer_unit_price_uzs', 10_000);

        DB::table('business_settings')->where('id', 1)->update(['markup_percent' => '12.50']);

        $this->asAdmin()->getJson($url)->assertJsonPath('data.customer_unit_price_uzs', 11_250);
        $this->assertSame(10_000, $product->fresh()?->market_price_uzs);
    }

    public function test_every_field_refuses_what_the_contract_and_the_table_refuse(): void
    {
        $archived = Category::factory()->archived()->create();

        foreach ([
            ['category_id', (string) Str::uuid()],
            ['category_id', 'not-a-uuid'],
            ['category_id', $archived->id],
            ['name_uz', ''],
            ['name_ru', str_repeat('я', 161)],
            ['unit_code', 'ton'],
            ['price_mode', 'range'],
            ['market_price_uzs', 0],
            ['market_price_uzs', '16000'],
            ['market_price_uzs', 16000.5],
            ['market_price_uzs', 1_000_000_001],
            ['sort_order', 100_001],
            ['is_active', 1],
        ] as [$field, $value]) {
            $this->asAdmin()->postJson(self::URL, $this->body([$field => $value]))
                ->assertStatus(422)
                ->assertJsonValidationErrorFor($field, 'errors');
        }

        $this->asAdmin()->postJson(self::URL, $this->body(['customer_unit_price_uzs' => 1]))
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('customer_unit_price_uzs', 'errors');

        $this->assertSame(0, Product::query()->count());
    }

    public function test_a_product_cannot_move_into_an_archived_category_or_become_active_while_archived(): void
    {
        $product = Product::factory()->create();
        $archivedCategory = Category::factory()->archived()->create();

        $this->asAdmin()->patchJson(self::URL.'/'.$product->id, ['category_id' => $archivedCategory->id])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('category_id', 'errors');

        $archivedProduct = Product::factory()->archived()->create();
        $this->asAdmin()->patchJson(self::URL.'/'.$archivedProduct->id, ['is_active' => true])
            ->assertStatus(409)
            ->assertJsonPath('code', 'business_conflict');
    }

    public function test_a_subset_updates_and_archive_and_restore_behave_as_for_categories(): void
    {
        $product = Product::factory()->create(['market_price_uzs' => 5_000]);
        $url = self::URL.'/'.$product->id;

        $this->asAdmin()->patchJson($url, ['market_price_uzs' => 6_000, 'is_active' => false])
            ->assertOk()
            ->assertJsonPath('data.market_price_uzs', 6_000)
            ->assertJsonPath('data.is_active', false)
            ->assertJsonPath('data.name_uz', $product->name_uz);

        $this->asAdmin()->postJson($url.'/archive')->assertOk()->assertJsonPath('data.is_active', false);
        $this->asAdmin()->postJson($url.'/archive')->assertOk();
        $this->asAdmin()->postJson($url.'/restore')->assertOk()
            ->assertJsonPath('data.is_active', true)
            ->assertJsonPath('data.archived_at', null);
    }

    public function test_archiving_a_category_leaves_its_products_alone(): void
    {
        $product = Product::factory()->create();

        $this->asAdmin()->postJson('/api/v1/admin/categories/'.$product->category_id.'/archive')->assertOk();

        $this->assertNull($product->fresh()?->archived_at);
        $this->assertTrue((bool) $product->fresh()?->is_active);
    }

    public function test_the_list_filters_by_category_and_searches_either_name_in_any_case(): void
    {
        $vegetables = Category::factory()->create();
        Product::factory()->create(['category_id' => $vegetables->id, 'name_uz' => 'Pomidor', 'name_ru' => 'Помидор']);
        Product::factory()->create(['category_id' => $vegetables->id, 'name_uz' => 'Bodring', 'name_ru' => 'Огурец']);
        Product::factory()->create(['name_uz' => 'Olma 50%', 'name_ru' => 'Яблоко']);
        Product::factory()->archived()->create(['category_id' => $vegetables->id, 'name_uz' => 'Qalampir', 'name_ru' => 'Перец']);

        $this->asAdmin()->getJson(self::URL.'?search='.urlencode('ПОМИД'))
            ->assertJsonPath('data.*.name_uz', ['Pomidor']);
        $this->asAdmin()->getJson(self::URL.'?search=bodr')
            ->assertJsonPath('data.*.name_ru', ['Огурец']);
        $this->asAdmin()->getJson(self::URL.'?search='.urlencode('50%'))
            ->assertJsonPath('data.*.name_uz', ['Olma 50%']);
        $this->asAdmin()->getJson(self::URL.'?search='.urlencode('%'))
            ->assertJsonPath('meta.pagination.total', 1);
        $this->asAdmin()->getJson(self::URL.'?search=_')
            ->assertJsonPath('meta.pagination.total', 0);

        $this->asAdmin()->getJson(self::URL.'?category_id='.$vegetables->id)
            ->assertJsonPath('meta.pagination.total', 2);
        $this->asAdmin()->getJson(self::URL.'?category_id='.$vegetables->id.'&include_archived=1')
            ->assertJsonPath('meta.pagination.total', 3);

        $this->asAdmin()->getJson(self::URL.'?category_id=not-a-uuid')->assertStatus(422);
        $this->asAdmin()->getJson(self::URL.'?search='.str_repeat('a', 101))->assertStatus(422);
    }

    public function test_every_role_but_admin_is_refused(): void
    {
        foreach ([Role::Operator, Role::Manager, Role::Courier, Role::Customer] as $role) {
            $token = User::factory()->role($role)->create()->createToken('t')->plainTextToken;

            $this->withToken($token)->getJson(self::URL)->assertStatus(403);
            $this->withToken($token)->postJson(self::URL, $this->body())->assertStatus(403);
        }

        $this->assertSame(0, Product::query()->count());
    }

    private function asAdmin(?User $admin = null): self
    {
        $admin ??= User::factory()->role(Role::Admin)->create();

        return $this->withToken($admin->createToken('t')->plainTextToken);
    }
}
