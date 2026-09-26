<?php

declare(strict_types=1);

namespace Tests\Feature\Catalog;

use App\Models\Category;
use App\Models\Enums\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * `/api/v1/admin/categories` (`docs/09` section 15, `BR-CAT-001`–`006`,
 * `DL-17` (14), `DL-18` (2)).
 */
final class AdminCategoriesApiTest extends TestCase
{
    use RefreshDatabase;

    private const URL = '/api/v1/admin/categories';

    public function test_an_admin_creates_a_category_and_is_recorded_as_its_creator(): void
    {
        $admin = User::factory()->role(Role::Admin)->create();

        $response = $this->asAdmin($admin)->postJson(self::URL, [
            'name_uz' => 'Sabzavotlar',
            'name_ru' => 'Овощи',
            'description_uz' => null,
            'sort_order' => 10,
        ])->assertCreated();

        $response->assertJsonPath('data.name_uz', 'Sabzavotlar')
            ->assertJsonPath('data.name_ru', 'Овощи')
            ->assertJsonPath('data.description_ru', null)
            ->assertJsonPath('data.sort_order', 10)
            ->assertJsonPath('data.is_active', true)
            ->assertJsonPath('data.archived_at', null);

        $category = Category::query()->findOrFail($response->json('data.id'));
        $this->assertSame($admin->id, $category->created_by_user_id);
    }

    public function test_both_names_are_required_and_bounded_and_nothing_undeclared_is_accepted(): void
    {
        foreach ([
            [['name_ru' => 'Овощи'], 'name_uz'],
            [['name_uz' => 'Sabzavot', 'name_ru' => '   '], 'name_ru'],
            [['name_uz' => str_repeat('a', 121), 'name_ru' => 'Овощи'], 'name_uz'],
            [['name_uz' => 'Sabzavot', 'name_ru' => 'Овощи', 'sort_order' => '1'], 'sort_order'],
            [['name_uz' => 'Sabzavot', 'name_ru' => 'Овощи', 'is_active' => 'yes'], 'is_active'],
            [['name_uz' => 'Sabzavot', 'name_ru' => 'Овощи', 'archived_at' => null], 'archived_at'],
            [['name_uz' => 'Sabzavot', 'name_ru' => 'Овощи', 'created_by_user_id' => (string) Str::uuid()], 'created_by_user_id'],
        ] as [$body, $field]) {
            $this->asAdmin()->postJson(self::URL, $body)
                ->assertStatus(422)
                ->assertJsonValidationErrorFor($field, 'errors');
        }

        $this->assertSame(0, Category::query()->count());
    }

    public function test_a_subset_updates_and_a_hidden_category_stays_unarchived(): void
    {
        $category = Category::factory()->create(['name_uz' => 'Eski', 'sort_order' => 1]);

        $this->asAdmin()->patchJson(self::URL.'/'.$category->id, ['name_uz' => 'Yangi', 'is_active' => false])
            ->assertOk()
            ->assertJsonPath('data.name_uz', 'Yangi')
            ->assertJsonPath('data.sort_order', 1)
            ->assertJsonPath('data.is_active', false)
            ->assertJsonPath('data.archived_at', null);
    }

    public function test_archive_and_restore_are_natural_repeats_and_restore_makes_it_active(): void
    {
        $category = Category::factory()->create(['is_active' => false]);
        $url = self::URL.'/'.$category->id;

        $archived = $this->asAdmin()->postJson($url.'/archive')->assertOk();
        $archived->assertJsonPath('data.is_active', false);
        $this->assertNotNull($archived->json('data.archived_at'));

        $this->asAdmin()->postJson($url.'/archive')
            ->assertOk()
            ->assertJsonPath('data.archived_at', $archived->json('data.archived_at'));

        $this->asAdmin()->postJson($url.'/restore')
            ->assertOk()
            ->assertJsonPath('data.archived_at', null)
            ->assertJsonPath('data.is_active', true);

        $this->asAdmin()->postJson($url.'/restore')->assertOk()->assertJsonPath('data.is_active', true);
    }

    public function test_an_archived_category_cannot_be_made_active_by_an_update(): void
    {
        $category = Category::factory()->archived()->create();

        $this->asAdmin()->patchJson(self::URL.'/'.$category->id, ['is_active' => true])
            ->assertStatus(409)
            ->assertJsonPath('code', 'business_conflict');

        $this->asAdmin()->patchJson(self::URL.'/'.$category->id, ['name_ru' => 'Архив'])
            ->assertOk()
            ->assertJsonPath('data.is_active', false);
    }

    public function test_the_list_is_paginated_ordered_and_hides_archived_unless_asked(): void
    {
        Category::factory()->create(['name_uz' => 'B', 'sort_order' => 2]);
        Category::factory()->create(['name_uz' => 'A', 'sort_order' => 2]);
        Category::factory()->create(['name_uz' => 'Z', 'sort_order' => 1]);
        Category::factory()->archived()->create(['name_uz' => 'Old', 'sort_order' => 0]);

        $this->asAdmin()->getJson(self::URL)
            ->assertOk()
            ->assertJsonPath('meta.pagination', ['page' => 1, 'per_page' => 20, 'total' => 3, 'last_page' => 1])
            ->assertJsonPath('data.*.name_uz', ['Z', 'A', 'B']);

        $this->asAdmin()->getJson(self::URL.'?include_archived=true&per_page=2&page=2')
            ->assertOk()
            ->assertJsonPath('meta.pagination', ['page' => 2, 'per_page' => 2, 'total' => 4, 'last_page' => 2])
            ->assertJsonPath('data.*.name_uz', ['A', 'B']);

        foreach (['per_page=0', 'per_page=101', 'page=0', 'include_archived=maybe'] as $query) {
            $this->asAdmin()->getJson(self::URL.'?'.$query)->assertStatus(422);
        }
    }

    public function test_a_missing_or_malformed_id_is_the_scope_safe_not_found(): void
    {
        foreach ([(string) Str::uuid(), 'not-a-uuid'] as $id) {
            $this->asAdmin()->getJson(self::URL.'/'.$id)->assertStatus(404)->assertJsonPath('code', 'resource_not_found');
            $this->asAdmin()->postJson(self::URL.'/'.$id.'/archive')->assertStatus(404);
        }
    }

    public function test_every_role_but_admin_is_refused(): void
    {
        $category = Category::factory()->create();

        foreach ([Role::Operator, Role::Manager, Role::Shopper, Role::Courier, Role::Customer] as $role) {
            $token = User::factory()->role($role)->create()->createToken('t')->plainTextToken;
            $url = self::URL.'/'.$category->id;

            foreach ([
                $this->withToken($token)->getJson(self::URL),
                $this->withToken($token)->postJson(self::URL, ['name_uz' => 'X', 'name_ru' => 'Х']),
                $this->withToken($token)->getJson($url),
                $this->withToken($token)->patchJson($url, ['name_uz' => 'X']),
                $this->withToken($token)->postJson($url.'/archive'),
                $this->withToken($token)->postJson($url.'/restore'),
            ] as $response) {
                $response->assertStatus(403)->assertJsonPath('code', 'forbidden');
            }
        }

        $this->assertNull($category->fresh()?->archived_at);
    }

    public function test_the_response_carries_exactly_the_documented_fields(): void
    {
        $category = Category::factory()->create();

        $data = $this->asAdmin()->getJson(self::URL.'/'.$category->id)->assertOk()->json('data');

        $this->assertSame(
            ['id', 'name_uz', 'name_ru', 'description_uz', 'description_ru', 'sort_order', 'is_active', 'archived_at', 'created_at', 'updated_at'],
            array_keys($data)
        );
        $this->assertMatchesRegularExpression('/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$/', $data['created_at']);
    }

    public function test_the_bounds_themselves_are_accepted(): void
    {
        $this->asAdmin()->postJson(self::URL, [
            'name_uz' => str_repeat('a', 120),
            'name_ru' => str_repeat('я', 120),
            'description_uz' => str_repeat('d', 2000),
            'sort_order' => -100_000,
        ])->assertCreated();

        $this->asAdmin()->postJson(self::URL, ['name_uz' => 'B', 'name_ru' => 'Б', 'sort_order' => 100_000])->assertCreated();
        $this->asAdmin()->postJson(self::URL, ['name_uz' => 'C', 'name_ru' => 'В', 'description_ru' => str_repeat('d', 2001)])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('description_ru', 'errors');
    }

    public function test_an_empty_or_unreadable_update_is_refused_and_changes_nothing(): void
    {
        $category = Category::factory()->create(['name_uz' => 'Eski']);
        $token = User::factory()->role(Role::Admin)->create()->createToken('t')->plainTextToken;

        $this->withToken($token)->patchJson(self::URL.'/'.$category->id, [])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('body', 'errors');
        $this->call('PATCH', self::URL.'/'.$category->id, [], [], [], [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_ACCEPT' => 'application/json',
            'HTTP_AUTHORIZATION' => 'Bearer '.$token,
        ], '{"name_uz": "X",')->assertStatus(400)->assertJsonPath('code', 'malformed_request');

        $this->assertSame('Eski', $category->fresh()?->name_uz);
    }

    public function test_an_empty_query_parameter_means_absent_and_an_absurd_page_is_refused(): void
    {
        Category::factory()->create();

        $this->asAdmin()->getJson(self::URL.'?include_archived=&page=&per_page=')
            ->assertOk()
            ->assertJsonPath('meta.pagination.page', 1)
            ->assertJsonPath('meta.pagination.per_page', 20);
        $this->asAdmin()->getJson(self::URL.'?page=100001')->assertStatus(422);
        $this->asAdmin()->getJson(self::URL.'?page=9223372036854775807')->assertStatus(422);
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
