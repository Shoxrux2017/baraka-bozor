<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `products`, as `docs/08-database.md` Section 7 names it.
 *
 * The customer price is deliberately not a column: it is the market price plus
 * the current markup (`BR-PRICE-001`), computed on every read, so a markup
 * change reaches every product at once and no stored price can go stale. The
 * order snapshots of Wave 2 are where a price is written down.
 *
 * The unit list is `BR-QTY-001`'s and the two price modes are `DL-2` 2.2's;
 * both are enforced here so that no seeder, command or console session can
 * store a product the domain does not know how to price or measure.
 */
return new class extends Migration
{
    /** @var list<string> */
    private const UNITS = ['kg', 'gram', 'piece', 'liter', 'package', 'box', 'bundle', 'meter'];

    /** @var list<string> */
    private const PRICE_MODES = ['fixed', 'estimate'];

    public function up(): void
    {
        Schema::create('products', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('category_id');
            $table->string('name_uz', 160);
            $table->string('name_ru', 160);
            $table->text('description_uz')->nullable();
            $table->text('description_ru')->nullable();
            $table->string('unit_code', 16);
            $table->string('price_mode', 16);
            $table->bigInteger('market_price_uzs');
            $table->boolean('is_active')->default(true);
            $table->integer('sort_order')->default(0);
            $table->timestampTz('archived_at')->nullable();
            $table->uuid('created_by_user_id');
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->index(['category_id', 'is_active']);
            $table->index(['is_active', 'sort_order']);
        });

        Schema::table('products', function (Blueprint $table): void {
            $table->foreign('category_id')
                ->references('id')
                ->on('categories')
                ->restrictOnDelete();

            $table->foreign('created_by_user_id')
                ->references('id')
                ->on('users')
                ->restrictOnDelete();
        });

        $this->check('products_unit_code_check', sprintf('unit_code in (%s)', $this->quoted(self::UNITS)));
        $this->check('products_price_mode_check', sprintf('price_mode in (%s)', $this->quoted(self::PRICE_MODES)));
        $this->check('products_market_price_positive_check', 'market_price_uzs > 0');
        $this->check('products_name_uz_not_blank_check', 'length(btrim(name_uz)) > 0');
        $this->check('products_name_ru_not_blank_check', 'length(btrim(name_ru)) > 0');
        $this->check('products_archived_inactive_check', 'archived_at is null or is_active = false');

        DB::statement('create index products_name_uz_lower_index on products (lower(name_uz))');
        DB::statement('create index products_name_ru_lower_index on products (lower(name_ru))');
    }

    public function down(): void
    {
        Schema::dropIfExists('products');
    }

    private function check(string $name, string $expression): void
    {
        DB::statement("alter table products add constraint {$name} check ({$expression})");
    }

    /**
     * @param  list<string>  $values
     */
    private function quoted(array $values): string
    {
        return implode(', ', array_map(static fn (string $value): string => "'{$value}'", $values));
    }
};
