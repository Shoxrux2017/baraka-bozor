<?php

declare(strict_types=1);

namespace Tests\Feature\Catalog;

use App\Exceptions\ApiException;
use App\Models\Category;
use App\Models\Enums\Role;
use App\Models\Product;
use App\Models\User;
use App\Modules\Catalog\Actions\SaveCatalogEntry;
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
        $product = Product::factory()->create();
        $url = self::URL.'/'.$product->id;

        foreach ([Role::Operator, Role::Manager, Role::Shopper, Role::Courier, Role::Customer] as $role) {
            $token = User::factory()->role($role)->create()->createToken('t')->plainTextToken;

            foreach ([
                $this->withToken($token)->getJson(self::URL),
                $this->withToken($token)->postJson(self::URL, $this->body()),
                $this->withToken($token)->getJson($url),
                $this->withToken($token)->patchJson($url, ['name_uz' => 'X']),
                $this->withToken($token)->postJson($url.'/archive'),
                $this->withToken($token)->postJson($url.'/restore'),
            ] as $response) {
                $response->assertStatus(403)->assertJsonPath('code', 'forbidden');
            }
        }

        $this->assertSame(1, Product::query()->count());
    }

    public function test_a_missing_or_malformed_id_is_the_scope_safe_not_found(): void
    {
        foreach ([(string) Str::uuid(), 'not-a-uuid'] as $id) {
            foreach ([
                $this->asAdmin()->getJson(self::URL.'/'.$id),
                $this->asAdmin()->patchJson(self::URL.'/'.$id, ['name_uz' => 'X']),
                $this->asAdmin()->postJson(self::URL.'/'.$id.'/archive'),
                $this->asAdmin()->postJson(self::URL.'/'.$id.'/restore'),
            ] as $response) {
                $response->assertStatus(404)->assertJsonPath('code', 'resource_not_found');
            }
        }
    }

    public function test_the_response_carries_exactly_the_documented_fields(): void
    {
        $data = $this->asAdmin()->getJson(self::URL.'/'.Product::factory()->create()->id)->assertOk()->json('data');

        $this->assertSame([
            'id', 'category_id', 'name_uz', 'name_ru', 'description_uz', 'description_ru', 'unit_code', 'price_mode',
            'market_price_uzs', 'customer_unit_price_uzs', 'sort_order', 'is_active', 'archived_at', 'created_at', 'updated_at',
        ], array_keys($data));
    }

    public function test_the_bounds_themselves_are_accepted(): void
    {
        $this->asAdmin()->postJson(self::URL, $this->body([
            'name_uz' => str_repeat('a', 160),
            'name_ru' => str_repeat('я', 160),
            'description_uz' => str_repeat('d', 2000),
            'description_ru' => null,
            'market_price_uzs' => 1_000_000_000,
            'sort_order' => 100_000,
            'is_active' => false,
        ]))->assertCreated()->assertJsonPath('data.is_active', false)->assertJsonPath('data.description_ru', null);

        $this->asAdmin()->postJson(self::URL, $this->body(['market_price_uzs' => 1, 'sort_order' => -100_000]))->assertCreated();
    }

    public function test_a_product_in_an_archived_category_can_still_be_edited_when_the_body_re_sends_its_category(): void
    {
        $category = Category::factory()->create();
        $product = Product::factory()->create(['category_id' => $category->id, 'name_uz' => 'Eski']);
        $category->forceFill(['archived_at' => now(), 'is_active' => false])->save();

        $this->asAdmin()->patchJson(self::URL.'/'.$product->id, ['category_id' => $category->id, 'name_uz' => 'Yangi'])
            ->assertOk()
            ->assertJsonPath('data.name_uz', 'Yangi');
        $this->asAdmin()->patchJson(self::URL.'/'.$product->id, ['category_id' => strtoupper($category->id), 'name_uz' => 'Yana'])
            ->assertOk();
    }

    public function test_an_edit_made_on_a_stale_read_is_decided_on_the_locked_row(): void
    {
        $stale = Product::factory()->create();
        Product::query()->whereKey($stale->id)->update(['archived_at' => now(), 'is_active' => false]);

        try {
            app(SaveCatalogEntry::class)->updateProduct($stale, ['is_active' => true]);
            $this->fail('An archived product was made active from a stale read.');
        } catch (ApiException $exception) {
            $this->assertSame(409, $exception->status());
            $this->assertSame('business_conflict', $exception->apiCode());
        }

        $this->assertFalse((bool) $stale->fresh()?->is_active);
    }

    public function test_an_empty_or_unreadable_update_is_refused_and_changes_nothing(): void
    {
        $product = Product::factory()->create(['market_price_uzs' => 5_000]);
        $token = User::factory()->role(Role::Admin)->create()->createToken('t')->plainTextToken;

        $this->withToken($token)->patchJson(self::URL.'/'.$product->id, [])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('body', 'errors');
        $this->call('PATCH', self::URL.'/'.$product->id, [], [], [], [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$token,
        ], '{"market_price_uzs": 6000,')->assertStatus(422);

        $this->assertSame(5_000, $product->fresh()?->market_price_uzs);
    }

    public function test_search_reads_yo_as_ye_every_uzbek_apostrophe_alike_and_a_backslash_literally(): void
    {
        Product::factory()->create(['name_uz' => 'Asal', 'name_ru' => 'Мёд']);
        Product::factory()->create(['name_uz' => "O'rik", 'name_ru' => 'Абрикос']);
        Product::factory()->create(['name_uz' => 'Back\\slash', 'name_ru' => 'Слэш']);

        $this->asAdmin()->getJson(self::URL.'?search='.urlencode('мед'))->assertJsonPath('data.*.name_uz', ['Asal']);
        $this->asAdmin()->getJson(self::URL.'?search='.urlencode('МЁД'))->assertJsonPath('data.*.name_uz', ['Asal']);
        foreach (['oʻrik', 'o‘rik', 'o’rik', 'o`rik', "O'RIK"] as $typed) {
            $this->asAdmin()->getJson(self::URL.'?search='.urlencode($typed))
                ->assertJsonPath('data.*.name_ru', ['Абрикос']);
        }
        $this->asAdmin()->getJson(self::URL.'?search='.urlencode('k\\s'))->assertJsonPath('data.*.name_ru', ['Слэш']);
        $this->asAdmin()->getJson(self::URL.'?search='.urlencode('   '))->assertJsonPath('meta.pagination.total', 3);
    }

    public function test_equal_sort_keys_keep_a_stable_order_across_pages(): void
    {
        foreach (range(1, 3) as $_) {
            Product::factory()->create(['name_uz' => 'Bir xil', 'sort_order' => 0]);
        }
        $expected = Product::query()->orderBy('id')->pluck('id')->all();

        $seen = [];
        foreach ([1, 2, 3] as $page) {
            $seen[] = $this->asAdmin()->getJson(self::URL.'?per_page=1&page='.$page)->json('data.0.id');
        }

        $this->assertSame($expected, $seen);
    }

    public function test_without_a_token_the_answer_is_authentication_required(): void
    {
        $this->getJson(self::URL)->assertStatus(401)->assertJsonPath('code', 'authentication_required');
    }

    private function asAdmin(?User $admin = null): self
    {
        $admin ??= User::factory()->role(Role::Admin)->create();

        return $this->withToken($admin->createToken('t')->plainTextToken);
    }
}
