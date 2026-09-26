<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `product_images`, as `docs/08-database.md` Section 8 names it: the metadata
 * of the one current image per product. The bytes live on the filesystem disk
 * under `storage_key`, which is unique because a fresh key is issued for every
 * upload so that the public URL changes when the image does (`DL-17`).
 *
 * `BR-CAT-004` in the database: one image per product (the unique
 * `product_id`), at most 5 MB, and only the three formats the product allows.
 * The application validates the bytes themselves; the table refuses metadata
 * that claims otherwise.
 */
return new class extends Migration
{
    /** Five mebibytes, the limit `BR-CAT-004` sets. */
    private const MAX_BYTES = 5 * 1024 * 1024;

    /** @var list<string> */
    private const MIME_TYPES = ['image/jpeg', 'image/png', 'image/webp'];

    public function up(): void
    {
        Schema::create('product_images', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('product_id')->unique();
            $table->string('storage_key', 255)->unique();
            $table->string('original_filename', 255)->nullable();
            $table->string('mime_type', 64);
            $table->bigInteger('size_bytes');
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');
        });

        Schema::table('product_images', function (Blueprint $table): void {
            $table->foreign('product_id')
                ->references('id')
                ->on('products')
                ->restrictOnDelete();
        });

        $this->check('product_images_size_bytes_check', sprintf('size_bytes between 1 and %d', self::MAX_BYTES));
        $this->check(
            'product_images_mime_type_check',
            sprintf('mime_type in (%s)', implode(', ', array_map(
                static fn (string $value): string => "'{$value}'",
                self::MIME_TYPES
            )))
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('product_images');
    }

    private function check(string $name, string $expression): void
    {
        DB::statement("alter table product_images add constraint {$name} check ({$expression})");
    }
};
