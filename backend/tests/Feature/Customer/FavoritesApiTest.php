<?php

declare(strict_types=1);

namespace Tests\Feature\Customer;

use App\Models\Category;
use App\Models\CustomerFavorite;
use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\Product;
use App\Models\User;
use App\Modules\Customer\CustomerFavorites;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * The Customer's favourite products (`docs/09` section 58, `BR-CAT-007`,
 * `DL-79` (5)).
 */
final class FavoritesApiTest extends TestCase
{
    use RefreshDatabase;

    private const URL = '/api/v1/customer/favorites';

    private User $customer;

    protected function setUp(): void
    {
        parent::setUp();

        $this->customer = User::factory()->customer()->create();
    }

    public function test_a_listed_product_is_added_and_listed_with_the_customer_price_only(): void
    {
        DB::table('business_settings')->where('id', 1)->update(['markup_percent' => '15.00']);
        $product = Product::factory()->create(['market_price_uzs' => 16_000]);

        $this->as($this->customer)->putJson(self::URL.'/'.$product->id)->assertNoContent();

        $response = $this->as($this->customer)->getJson(self::URL)->assertOk();
        $response->assertJsonPath('data.0.id', $product->id)
            ->assertJsonPath('data.0.is_favorite', true)
            ->assertJsonPath('data.0.is_available', true)
            ->assertJsonPath('data.0.customer_unit_price_uzs', 18_400)
            ->assertJsonPath('meta.pagination.total', 1);
        $this->assertArrayNotHasKey('market_price_uzs', $response->json('data.0'));
    }

    public function test_adding_twice_keeps_one_row(): void
    {
        $product = Product::factory()->create();

        $this->as($this->customer)->putJson(self::URL.'/'.$product->id)->assertNoContent();
        $this->as($this->customer)->putJson(self::URL.'/'.$product->id)->assertNoContent();

        $this->assertSame(1, CustomerFavorite::query()->count());
    }

    public function test_a_product_the_customer_cannot_see_or_an_unknown_id_is_not_found(): void
    {
        $inactive = Product::factory()->create(['is_active' => false]);
        $archived = Product::factory()->archived()->create();
        $inArchivedCategory = Product::factory()->for(Category::factory()->archived())->create();

        foreach ([$inactive->id, $archived->id, $inArchivedCategory->id, (string) Str::uuid(), 'not-a-uuid'] as $id) {
            $this->as($this->customer)->putJson(self::URL.'/'.$id)
                ->assertStatus(404)->assertJsonPath('code', 'resource_not_found');
        }

        $this->assertSame(0, CustomerFavorite::query()->count());
    }

    public function test_a_body_is_refused_on_put_and_delete(): void
    {
        $product = Product::factory()->create();

        $this->as($this->customer)->putJson(self::URL.'/'.$product->id, ['x' => 1])
            ->assertStatus(422)->assertJsonPath('code', 'validation_failed');
        $this->as($this->customer)->deleteJson(self::URL.'/'.$product->id, ['x' => 1])
            ->assertStatus(422)->assertJsonPath('code', 'validation_failed');

        $this->assertSame(0, CustomerFavorite::query()->count());
    }

    public function test_delete_removes_a_favourite_and_answers_204_whatever_the_product(): void
    {
        $product = Product::factory()->create();
        $archived = Product::factory()->archived()->create();
        CustomerFavorite::factory()->create(['customer_id' => $this->customer->id, 'product_id' => $product->id]);

        $this->as($this->customer)->deleteJson(self::URL.'/'.$product->id)->assertNoContent();
        $this->assertSame(0, CustomerFavorite::query()->count());

        $this->as($this->customer)->deleteJson(self::URL.'/'.$product->id)->assertNoContent();
        $this->as($this->customer)->deleteJson(self::URL.'/'.Str::uuid())->assertNoContent();
        $this->as($this->customer)->deleteJson(self::URL.'/'.$archived->id)->assertNoContent();
    }

    public function test_one_customer_never_sees_or_removes_anothers_favourites(): void
    {
        $other = User::factory()->customer()->create();
        $product = Product::factory()->create();
        CustomerFavorite::factory()->create(['customer_id' => $this->customer->id, 'product_id' => $product->id]);
        CustomerFavorite::factory()->create(['customer_id' => $other->id, 'product_id' => $product->id]);

        $this->as($other)->deleteJson(self::URL.'/'.$product->id)->assertNoContent();

        $this->assertSame(1, CustomerFavorite::query()->where('customer_id', $this->customer->id)->count());
        $this->assertSame(0, CustomerFavorite::query()->where('customer_id', $other->id)->count());
        $this->as($other)->getJson(self::URL)->assertOk()->assertJsonPath('meta.pagination.total', 0);
        $this->as($other)->getJson('/api/v1/catalog/products')
            ->assertOk()->assertJsonPath('data.0.is_favorite', false);
        $this->as($this->customer)->getJson('/api/v1/catalog/products')
            ->assertOk()->assertJsonPath('data.0.is_favorite', true);
    }

    public function test_a_favourite_that_stops_being_sold_stays_listed_as_unavailable(): void
    {
        $archived = Product::factory()->create();
        $inactiveCategory = Product::factory()->for(Category::factory())->create();
        $sold = Product::factory()->create();
        foreach ([$archived, $inactiveCategory, $sold] as $product) {
            CustomerFavorite::factory()->create(['customer_id' => $this->customer->id, 'product_id' => $product->id]);
        }

        $archived->forceFill(['is_active' => false, 'archived_at' => now()])->save();
        $inactiveCategory->category->forceFill(['is_active' => false, 'archived_at' => now()])->save();

        $availability = collect($this->as($this->customer)->getJson(self::URL)->assertOk()->json('data'))
            ->pluck('is_available', 'id');

        $this->assertFalse($availability[$archived->id]);
        $this->assertFalse($availability[$inactiveCategory->id]);
        $this->assertTrue($availability[$sold->id]);
    }

    public function test_the_list_is_newest_first_and_equal_times_fall_back_to_id(): void
    {
        $products = Product::factory()->count(3)->create();

        foreach ($products as $i => $product) {
            $this->travelTo(now()->startOfSecond()->addMinutes($i));
            $this->as($this->customer)->putJson(self::URL.'/'.$product->id)->assertNoContent();
        }

        $this->as($this->customer)->getJson(self::URL)
            ->assertJsonPath('data.*.id', [$products[2]->id, $products[1]->id, $products[0]->id]);

        $this->travelBack();
        CustomerFavorite::query()->where('customer_id', $this->customer->id)->update(['created_at' => '2026-01-01 00:00:00+00']);
        $byId = CustomerFavorite::query()->where('customer_id', $this->customer->id)->orderByDesc('id')->pluck('product_id')->all();

        $this->as($this->customer)->getJson(self::URL)->assertJsonPath('data.*.id', $byId);
    }

    public function test_the_501st_favourite_is_refused_but_an_existing_one_is_accepted_again(): void
    {
        $products = Product::factory()->count(CustomerFavorites::LIMIT)->create();
        $now = now();
        DB::table('customer_favorites')->insert($products->map(fn (Product $product): array => [
            'id' => (string) Str::uuid(),
            'customer_id' => $this->customer->id,
            'product_id' => $product->id,
            'created_at' => $now,
        ])->all());
        $new = Product::factory()->create();

        $this->as($this->customer)->putJson(self::URL.'/'.$new->id)
            ->assertStatus(409)
            ->assertJsonPath('code', 'favorites_full')
            ->assertJsonPath('details.limit', 500);
        $this->as($this->customer)->putJson(self::URL.'/'.$products[0]->id)->assertNoContent();

        $this->assertSame(CustomerFavorites::LIMIT, CustomerFavorite::query()->count());
    }

    public function test_only_a_customer_session_may_use_favourites(): void
    {
        $product = Product::factory()->create();
        $shopper = User::factory()->role(Role::Shopper)->create();

        $this->as($shopper)->getJson(self::URL)->assertStatus(403);
        $this->as($shopper)->putJson(self::URL.'/'.$product->id)->assertStatus(403);
        $this->as($shopper)->deleteJson(self::URL.'/'.$product->id)->assertStatus(403);

        $token = $this->customer->createToken('t')->plainTextToken;
        $this->customer->forceFill(['status' => UserStatus::Blocked, 'blocked_at' => now()])->save();
        $this->withToken($token)->getJson(self::URL)
            ->assertStatus(401)->assertJsonPath('code', 'account_blocked');
        $this->withToken($this->customer->createToken('t')->plainTextToken)->putJson(self::URL.'/'.$product->id)
            ->assertStatus(401)->assertJsonPath('code', 'account_blocked');
        $this->withToken($this->customer->createToken('t')->plainTextToken)->deleteJson(self::URL.'/'.$product->id)
            ->assertStatus(401)->assertJsonPath('code', 'account_blocked');
    }

    public function test_without_a_token_the_answer_is_authentication_required(): void
    {
        $product = Product::factory()->create();

        $this->getJson(self::URL)->assertStatus(401);
        $this->putJson(self::URL.'/'.$product->id)->assertStatus(401);
        $this->deleteJson(self::URL.'/'.$product->id)->assertStatus(401);
        $this->assertSame(0, CustomerFavorite::query()->count());
    }

    private function as(User $user): self
    {
        return $this->withToken($user->createToken('t')->plainTextToken);
    }
}
