<?php

declare(strict_types=1);

namespace Tests\Feature\Catalog;

use App\Models\Category;
use App\Models\CategoryImage;
use App\Models\Enums\Role;
use App\Models\User;
use Exception;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Testing\TestResponse;
use Tests\Support\ImageBytes;
use Tests\TestCase;

/**
 * `POST|DELETE /api/v1/admin/categories/{category}/image` (`docs/09` section
 * 16, `BR-CAT-004`, `DL-79` (2)).
 */
final class AdminCategoryImageApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('public');
    }

    protected function tearDown(): void
    {
        ImageBytes::cleanUp();

        parent::tearDown();
    }

    public function test_jpeg_png_and_webp_each_upload_under_a_fresh_key_and_answer_the_public_url(): void
    {
        foreach ([
            ['jpg', ImageBytes::jpeg()],
            ['png', ImageBytes::png()],
            ['webp', ImageBytes::webp()],
        ] as [$extension, $file]) {
            $category = Category::factory()->create();

            $response = $this->upload($category, $file)->assertOk();

            $image = CategoryImage::query()->where('category_id', $category->id)->firstOrFail();
            $this->assertMatchesRegularExpression('#^categories/[0-9a-f-]{36}\.'.$extension.'$#', $image->storage_key);
            Storage::disk('public')->assertExists($image->storage_key);
            $response->assertJsonPath('data.id', $category->id);
            $response->assertJsonPath('data.image_url', Storage::disk('public')->url($image->storage_key));
            $this->assertStringEndsWith('/storage/'.$image->storage_key, (string) $response->json('data.image_url'));
            $this->assertSame(1, CategoryImage::query()->where('category_id', $category->id)->count());
        }
    }

    public function test_the_bytes_decide_the_format_and_the_size_is_capped_at_five_mebibytes(): void
    {
        $category = Category::factory()->create();

        $this->upload($category, ImageBytes::pngNamedJpeg())->assertOk();
        $image = CategoryImage::query()->where('category_id', $category->id)->firstOrFail();
        $this->assertStringEndsWith('.png', $image->storage_key);
        $this->assertSame('image/png', $image->mime_type);

        foreach ([
            ImageBytes::pdfNamedJpeg(),
            ImageBytes::gif(),
            ImageBytes::svgNamedPng(),
            ImageBytes::htmlNamedPng(),
            ImageBytes::emptyFile(),
            ImageBytes::pngOfSize(5 * 1024 * 1024 + 1),
        ] as $file) {
            $this->upload($category, $file)->assertStatus(422)->assertJsonValidationErrorFor('image', 'errors');
        }

        $this->upload($category, ImageBytes::pngOfSize(5 * 1024 * 1024))->assertOk();
    }

    public function test_a_replacement_changes_the_url_and_removes_the_previous_file(): void
    {
        $category = Category::factory()->create();

        $first = $this->upload($category, ImageBytes::png())->assertOk()->json('data.image_url');
        $firstKey = (string) CategoryImage::query()->where('category_id', $category->id)->value('storage_key');

        $second = $this->upload($category, ImageBytes::jpeg())->assertOk()->json('data.image_url');
        $secondKey = (string) CategoryImage::query()->where('category_id', $category->id)->value('storage_key');

        $this->assertNotSame($first, $second);
        $this->assertSame(1, CategoryImage::query()->where('category_id', $category->id)->count());
        Storage::disk('public')->assertMissing($firstKey);
        Storage::disk('public')->assertExists($secondKey);
    }

    public function test_removal_deletes_the_row_and_the_file_and_repeats_naturally(): void
    {
        $category = Category::factory()->create();
        $this->upload($category, ImageBytes::png())->assertOk();
        $key = (string) CategoryImage::query()->where('category_id', $category->id)->value('storage_key');

        $this->asAdmin()->deleteJson($this->url($category))->assertOk()->assertJsonPath('data.image_url', null);

        Storage::disk('public')->assertMissing($key);
        $this->assertSame(0, CategoryImage::query()->count());

        $this->asAdmin()->deleteJson($this->url($category))->assertOk()->assertJsonPath('data.image_url', null);
    }

    public function test_the_file_must_come_under_image_and_nothing_else_is_accepted(): void
    {
        $category = Category::factory()->create();

        $this->asAdmin()->post($this->url($category), ['photo' => ImageBytes::png()], ['Accept' => 'application/json'])
            ->assertStatus(422)
            ->assertJsonPath('code', 'validation_failed');
        $this->asAdmin()->post($this->url($category), [], ['Accept' => 'application/json'])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('image', 'errors');

        $this->assertSame(0, CategoryImage::query()->count());
    }

    public function test_an_archived_category_accepts_a_picture(): void
    {
        $this->upload(Category::factory()->archived()->create(), ImageBytes::png())->assertOk();

        $this->assertSame(1, CategoryImage::query()->count());
    }

    public function test_a_missing_category_is_not_found_and_leaves_no_file(): void
    {
        $this->asAdmin()->post('/api/v1/admin/categories/'.fake()->uuid().'/image', ['image' => ImageBytes::png()], ['Accept' => 'application/json'])
            ->assertStatus(404)
            ->assertJsonPath('code', 'resource_not_found');

        $this->assertSame([], Storage::disk('public')->allFiles('categories'));
    }

    public function test_a_customer_is_refused_and_no_token_is_unauthenticated(): void
    {
        $category = Category::factory()->create();
        $token = User::factory()->role(Role::Customer)->create()->createToken('t')->plainTextToken;

        $this->withToken($token)->post($this->url($category), ['image' => ImageBytes::png()], ['Accept' => 'application/json'])
            ->assertStatus(403);
        $this->withToken($token)->deleteJson($this->url($category))->assertStatus(403);
        $this->flushHeaders();
        $this->post($this->url($category), ['image' => ImageBytes::png()], ['Accept' => 'application/json'])->assertStatus(401);
        $this->deleteJson($this->url($category))->assertStatus(401);

        $this->assertSame(0, CategoryImage::query()->count());
    }

    public function test_an_upload_that_loses_a_race_for_the_first_picture_is_a_conflict_and_leaves_no_file(): void
    {
        $category = Category::factory()->create();
        CategoryImage::creating(static function (): void {
            throw new UniqueConstraintViolationException('pgsql', 'insert into "category_images"', [], new Exception('duplicate key'));
        });

        $this->upload($category, ImageBytes::png())->assertStatus(409)->assertJsonPath('code', 'business_conflict');

        $this->assertSame([], Storage::disk('public')->allFiles('categories'));
        $this->assertSame(0, CategoryImage::query()->count());
    }

    private function upload(Category $category, UploadedFile $file): TestResponse
    {
        return $this->asAdmin()->post($this->url($category), ['image' => $file], ['Accept' => 'application/json']);
    }

    private function url(Category $category): string
    {
        return '/api/v1/admin/categories/'.$category->id.'/image';
    }

    private function asAdmin(): self
    {
        return $this->withToken(User::factory()->role(Role::Admin)->create()->createToken('t')->plainTextToken);
    }
}
