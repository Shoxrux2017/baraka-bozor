<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `customer_favorites` (`docs/08-database.md` Section 32, `BR-CAT-007`,
 * `DL-79` (5)): one row per Customer and product. The index serves the
 * Customer's list, newest first.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('customer_favorites', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('customer_id')->constrained('users')->restrictOnDelete();
            $table->foreignUuid('product_id')->constrained('products')->restrictOnDelete();
            $table->timestampTz('created_at');
            $table->unique(['customer_id', 'product_id']);
        });

        DB::statement('create index customer_favorites_customer_created_idx on customer_favorites (customer_id, created_at desc, id desc)');
    }

    public function down(): void
    {
        Schema::dropIfExists('customer_favorites');
    }
};
