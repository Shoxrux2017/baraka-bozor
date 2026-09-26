<?php

declare(strict_types=1);

namespace Tests\Feature\Catalog;

use App\Models\Enums\Role;
use App\Models\Product;
use App\Models\ProductImage;
use App\Models\User;
use Exception;
use Illuminate\Contracts\Filesystem\Filesystem;
use Illuminate\Database\UniqueConstraintViolationException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Illuminate\Testing\TestResponse;
use Mockery;
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

    protected function tearDown(): void
    {
        ImageBytes::cleanUp();

        parent::tearDown();
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

        foreach ([
            ImageBytes::pdfNamedJpeg(),
            ImageBytes::gif(),
            ImageBytes::svgNamedPng(),
            ImageBytes::htmlNamedPng(),
            ImageBytes::emptyFile(),
            ImageBytes::pngOfSize(5 * 1024 * 1024 + 1),
        ] as $file) {
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

        foreach ([Role::Operator, Role::Manager, Role::Shopper, Role::Courier, Role::Customer] as $role) {
            $token = User::factory()->role($role)->create()->createToken('t')->plainTextToken;

            $this->withToken($token)->post($this->url($product), ['image' => ImageBytes::png()], ['Accept' => 'application/json'])
                ->assertStatus(403)
                ->assertJsonPath('code', 'forbidden');
            $this->withToken($token)->deleteJson($this->url($product))->assertStatus(403)->assertJsonPath('code', 'forbidden');
        }

        $this->assertSame(0, ProductImage::query()->count());
    }

    public function test_the_stored_extension_follows_the_bytes_not_the_name(): void
    {
        $product = Product::factory()->create();

        $this->upload($product, ImageBytes::pngNamedJpeg())->assertOk();

        $image = ProductImage::query()->where('product_id', $product->id)->firstOrFail();
        $this->assertStringEndsWith('.png', $image->storage_key);
        $this->assertSame('image/png', $image->mime_type);
    }

    public function test_only_one_file_under_image_and_no_other_file_field_is_accepted(): void
    {
        $product = Product::factory()->create();

        $this->asAdmin()->post($this->url($product), ['image' => [ImageBytes::png(), ImageBytes::png()]], ['Accept' => 'application/json'])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('image', 'errors');
        $this->asAdmin()->post($this->url($product), ['image' => ImageBytes::png(), 'extra' => ImageBytes::png()], ['Accept' => 'application/json'])
            ->assertStatus(422)
            ->assertJsonValidationErrorFor('extra', 'errors');

        $this->assertSame(0, ProductImage::query()->count());
    }

    public function test_a_write_the_disk_reports_as_failed_changes_nothing(): void
    {
        $product = Product::factory()->create();
        $this->upload($product, ImageBytes::png())->assertOk();
        $key = (string) ProductImage::query()->where('product_id', $product->id)->value('storage_key');
        $healthy = Storage::disk('public');

        $failing = Mockery::mock(Filesystem::class);
        $failing->shouldReceive('putFileAs')->once()->andReturn(false);
        $failing->shouldNotReceive('delete');
        Storage::set('public', $failing);

        $this->upload($product, ImageBytes::jpeg())->assertStatus(500)->assertJsonPath('code', 'server_error');

        Storage::set('public', $healthy);
        $this->assertSame($key, ProductImage::query()->where('product_id', $product->id)->value('storage_key'));
        Storage::disk('public')->assertExists($key);
    }

    public function test_an_upload_that_loses_a_race_for_the_first_image_is_a_conflict_and_leaves_no_file(): void
    {
        $product = Product::factory()->create();
        ProductImage::creating(static function (): void {
            throw new UniqueConstraintViolationException('pgsql', 'insert into "product_images"', [], new Exception('duplicate key'));
        });

        $this->upload($product, ImageBytes::png())->assertStatus(409)->assertJsonPath('code', 'business_conflict');

        $this->assertSame([], Storage::disk('public')->allFiles('products'));
        $this->assertSame(0, ProductImage::query()->count());
    }

    public function test_lists_and_details_carry_the_image_url_without_a_query_per_product(): void
    {
        $products = Product::factory()->count(3)->create();
        foreach ($products as $product) {
            $this->upload($product, ImageBytes::png())->assertOk();
        }
        $token = User::factory()->role(Role::Admin)->create()->createToken('t')->plainTextToken;

        DB::enableQueryLog();
        $list = $this->withToken($token)->getJson('/api/v1/admin/products')->assertOk();
        $queries = count(DB::getQueryLog());
        DB::disableQueryLog();

        $this->assertCount(3, array_filter($list->json('data.*.image_url')));
        $this->assertLessThanOrEqual(8, $queries, 'Loading images one product at a time would grow with the page.');
        $this->withToken($token)->getJson('/api/v1/admin/products/'.$products[0]->id)
            ->assertJsonPath('data.image_url', Storage::disk('public')->url(
                (string) ProductImage::query()->where('product_id', $products[0]->id)->value('storage_key')
            ));
    }

    public function test_a_body_above_the_server_limit_is_payload_too_large_not_not_found(): void
    {
        $product = Product::factory()->create();

        $this->asAdmin()->call('POST', $this->url($product), [], [], [], [
            'CONTENT_LENGTH' => (string) (9 * 1024 * 1024),
            'CONTENT_TYPE' => 'multipart/form-data; boundary=x',
            'HTTP_ACCEPT' => 'application/json',
        ])->assertStatus(413)->assertJsonPath('code', 'payload_too_large');
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
