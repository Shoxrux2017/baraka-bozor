<?php

declare(strict_types=1);

namespace Tests\Feature\Catalog;

use App\Models\Enums\Role;
use App\Models\Product;
use App\Models\ProductImage;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Storage;
use Illuminate\Testing\TestResponse;
use Tests\Support\ImageBytes;
use Tests\TestCase;

/**
 * `POST|DELETE /api/v1/admin/products/{product}/image` (`docs/09` section 16,
 * `BR-CAT-004`, `DL-17` (5)).
 */
final class AdminProductImageApiTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        Storage::fake('public');
    }

    public function test_an_upload_stores_the_file_under_a_fresh_key_and_answers_its_public_url(): void
    {
        $product = Product::factory()->create();

        $response = $this->upload($product, ImageBytes::webp())->assertOk();

        $image = ProductImage::query()->where('product_id', $product->id)->firstOrFail();
        $this->assertMatchesRegularExpression('#^products/[0-9a-f-]{36}\.webp$#', $image->storage_key);
        $this->assertSame('image/webp', $image->mime_type);
        $this->assertSame('pomidor.webp', $image->original_filename);
        Storage::disk('public')->assertExists($image->storage_key);
        $response->assertJsonPath('data.image_url', Storage::disk('public')->url($image->storage_key));
        $response->assertJsonPath('data.id', $product->id);
    }

    public function test_a_replacement_changes_the_url_and_removes_the_previous_file(): void
    {
        $product = Product::factory()->create();

        $first = $this->upload($product, ImageBytes::png())->assertOk()->json('data.image_url');
        $firstKey = ProductImage::query()->where('product_id', $product->id)->value('storage_key');

        $second = $this->upload($product, ImageBytes::jpeg())->assertOk()->json('data.image_url');
        $secondKey = ProductImage::query()->where('product_id', $product->id)->value('storage_key');

        $this->assertNotSame($first, $second);
        $this->assertStringEndsWith('.jpg', (string) $secondKey);
        $this->assertSame(1, ProductImage::query()->where('product_id', $product->id)->count());
        Storage::disk('public')->assertMissing((string) $firstKey);
        Storage::disk('public')->assertExists((string) $secondKey);
    }

    public function test_removal_deletes_the_row_and_the_file_and_repeats_naturally(): void
    {
        $product = Product::factory()->create();
        $this->upload($product, ImageBytes::png())->assertOk();
        $key = (string) ProductImage::query()->where('product_id', $product->id)->value('storage_key');

        $this->asAdmin()->deleteJson($this->url($product))->assertOk()->assertJsonPath('data.image_url', null);

        Storage::disk('public')->assertMissing($key);
        $this->assertSame(0, ProductImage::query()->count());

        $this->asAdmin()->deleteJson($this->url($product))->assertOk()->assertJsonPath('data.image_url', null);
    }

    public function test_the_bytes_decide_the_format_and_the_size_is_capped_at_five_mebibytes(): void
    {
        $product = Product::factory()->create();

        foreach ([ImageBytes::pdfNamedJpeg(), ImageBytes::gif(), ImageBytes::pngOfSize(5 * 1024 * 1024 + 1)] as $file) {
            $this->upload($product, $file)->assertStatus(422)->assertJsonValidationErrorFor('image', 'errors');
        }

        $this->asAdmin()->post($this->url($product), [], ['Accept' => 'application/json'])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('image', 'errors');

        $this->upload($product, ImageBytes::pngOfSize(5 * 1024 * 1024))->assertOk();
    }

    public function test_an_archived_product_accepts_an_image_and_a_missing_one_is_not_found(): void
    {
        $this->upload(Product::factory()->archived()->create(), ImageBytes::png())->assertOk();

        $this->asAdmin()->post('/api/v1/admin/products/'.fake()->uuid().'/image', ['image' => ImageBytes::png()], ['Accept' => 'application/json'])
            ->assertStatus(404)
            ->assertJsonPath('code', 'resource_not_found');
        $this->assertCount(1, Storage::disk('public')->allFiles('products'), 'The refused upload left no file behind.');
    }

    public function test_every_role_but_admin_is_refused(): void
    {
        $product = Product::factory()->create();

        foreach ([Role::Operator, Role::Manager, Role::Customer] as $role) {
            $token = User::factory()->role($role)->create()->createToken('t')->plainTextToken;

            $this->withToken($token)->post($this->url($product), ['image' => ImageBytes::png()], ['Accept' => 'application/json'])
                ->assertStatus(403)
                ->assertJsonPath('code', 'forbidden');
            $this->withToken($token)->deleteJson($this->url($product))->assertStatus(403);
        }

        $this->assertSame(0, ProductImage::query()->count());
    }

    private function upload(Product $product, UploadedFile $file): TestResponse
    {
        return $this->asAdmin()->post($this->url($product), ['image' => $file], ['Accept' => 'application/json']);
    }

    private function url(Product $product): string
    {
        return '/api/v1/admin/products/'.$product->id.'/image';
    }

    private function asAdmin(): self
    {
        return $this->withToken(User::factory()->role(Role::Admin)->create()->createToken('t')->plainTextToken);
    }
}
