<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use App\Models\Product;
use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Feature\Identity\AssertsDatabaseRejections;
use Tests\Feature\Identity\ReadsPostgresCatalog;
use Tests\TestCase;

/**
 * `product_images`, as `docs/08-database.md` Section 8 names it.
 */
final class ProductImagesTableTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    private const TABLE = 'product_images';

    /**
     * @return array<string, array{string, bool}>
     */
    private function expectedColumns(): array
    {
        return [
            'id' => ['uuid', false],
            'product_id' => ['uuid', false],
            'storage_key' => ['character varying', false],
            'original_filename' => ['character varying', true],
            'mime_type' => ['character varying', false],
            'size_bytes' => ['bigint', false],
            'created_at' => ['timestamp with time zone', false],
            'updated_at' => ['timestamp with time zone', false],
        ];
    }

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function row(array $overrides = []): array
    {
        return array_merge([
            'id' => (string) Str::uuid(),
            'product_id' => Product::factory()->create()->id,
            'storage_key' => 'products/'.Str::uuid().'.webp',
            'original_filename' => 'pomidor.webp',
            'mime_type' => 'image/webp',
            'size_bytes' => 120_000,
            'created_at' => now(),
            'updated_at' => now(),
        ], $overrides);
    }

    public function test_it_has_exactly_the_columns_the_schema_names_with_their_types(): void
    {
        $actual = $this->columnsOf(self::TABLE);
        $expected = $this->expectedColumns();

        $names = array_keys($actual);
        $expectedNames = array_keys($expected);
        sort($names);
        sort($expectedNames);
        $this->assertSame($expectedNames, $names);

        foreach ($expected as $column => [$type, $nullable]) {
            $this->assertSame($type, $actual[$column]->data_type, self::TABLE.".{$column} type");
            $this->assertSame($nullable ? 'YES' : 'NO', $actual[$column]->is_nullable, self::TABLE.".{$column} nullability");
        }
    }

    public function test_a_product_holds_at_most_one_image(): void
    {
        $product = Product::factory()->create();
        DB::table(self::TABLE)->insert($this->row(['product_id' => $product->id]));

        $this->assertRejectedBy(
            self::TABLE,
            'product_images_product_id_unique',
            $this->row(['product_id' => $product->id]),
            'BR-CAT-004: one current image per product; a replacement rewrites the row.'
        );
    }

    public function test_a_storage_key_is_never_shared(): void
    {
        $key = 'products/'.Str::uuid().'.png';
        DB::table(self::TABLE)->insert($this->row(['storage_key' => $key, 'mime_type' => 'image/png']));

        $this->assertRejectedBy(
            self::TABLE,
            'product_images_storage_key_unique',
            $this->row(['storage_key' => $key, 'mime_type' => 'image/png']),
            'Two rows pointing at one file would let a delete of either remove the other\'s image.'
        );
    }

    public function test_a_size_outside_one_byte_to_five_megabytes_is_rejected(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'product_images_size_bytes_check',
            $this->row(['size_bytes' => 0]),
            'An empty image is not an image.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'product_images_size_bytes_check',
            $this->row(['size_bytes' => 5 * 1024 * 1024 + 1]),
            'BR-CAT-004 caps an image at 5 MB.'
        );
    }

    public function test_a_format_outside_jpeg_png_and_webp_is_rejected(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'product_images_mime_type_check',
            $this->row(['mime_type' => 'image/gif']),
            'BR-CAT-004 allows JPEG, PNG and WebP only.'
        );
    }

    public function test_a_product_cannot_be_deleted_while_an_image_refers_to_it(): void
    {
        $product = Product::factory()->create();
        DB::table(self::TABLE)->insert($this->row(['product_id' => $product->id]));

        $this->expectException(QueryException::class);
        $this->expectExceptionMessage('product_images_product_id_foreign');

        DB::table('products')->where('id', $product->id)->delete();
    }
}
