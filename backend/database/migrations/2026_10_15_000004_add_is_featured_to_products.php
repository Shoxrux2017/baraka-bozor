<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `products.is_featured`, the Admin's "Рекомендуем" mark (`docs/08-database.md`
 * Section 7, `DL-79`). The partial index serves the home row: it holds only
 * the marked products, in the order the shop lists them.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('products', function (Blueprint $table): void {
            $table->boolean('is_featured')->default(false);
        });

        DB::statement('create index products_featured_idx on products (sort_order, name_uz, id) where is_featured');
    }

    public function down(): void
    {
        DB::statement('drop index if exists products_featured_idx');

        Schema::table('products', function (Blueprint $table): void {
            $table->dropColumn('is_featured');
        });
    }
};
