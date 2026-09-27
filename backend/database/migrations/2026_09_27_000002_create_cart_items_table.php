<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `cart_items`, as `docs/08-database.md` Section 10 names it.
 *
 * A product appears at most once per cart (`BR-CART-002`), so a second add is
 * a conflict rather than a second line. The unit's precision and the bounds of
 * `DL-37` (6) are the application's; the database keeps the quantity positive
 * and within `numeric(18,3)`.
 */
return new class extends Migration
{
    /** @var list<string> */
    private const POLICIES = ['allow_similar_substitution', 'contact_before_substitution', 'remove_if_unavailable'];

    public function up(): void
    {
        Schema::create('cart_items', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('cart_id');
            $table->uuid('product_id');
            $table->decimal('quantity', 18, 3);
            $table->string('customer_note', 300)->nullable();
            $table->string('substitution_policy', 40)->default('allow_similar_substitution');
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->unique(['cart_id', 'product_id']);
        });

        Schema::table('cart_items', function (Blueprint $table): void {
            $table->foreign('cart_id')
                ->references('id')
                ->on('carts')
                ->restrictOnDelete();

            $table->foreign('product_id')
                ->references('id')
                ->on('products')
                ->restrictOnDelete();
        });

        DB::statement('alter table cart_items add constraint cart_items_quantity_positive_check check (quantity > 0)');
        DB::statement(sprintf(
            'alter table cart_items add constraint cart_items_substitution_policy_check check (substitution_policy in (%s))',
            implode(', ', array_map(static fn (string $value): string => "'{$value}'", self::POLICIES))
        ));
    }

    public function down(): void
    {
        Schema::dropIfExists('cart_items');
    }
};
