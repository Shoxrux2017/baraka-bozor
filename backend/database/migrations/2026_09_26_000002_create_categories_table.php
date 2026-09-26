<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `categories`, as `docs/08-database.md` Section 6 names it: a flat list
 * ordered by `sort_order` (`BR-CAT-006`), names required in both languages
 * (`BR-CAT-005`), archived rather than deleted (`BR-CAT-002`).
 *
 * `archived_at` and `is_active` are two columns for two questions — "is this
 * shown?" and "when was it taken out of use?" — and the check below keeps them
 * from disagreeing: an archived category is never active.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('categories', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->string('name_uz', 120);
            $table->string('name_ru', 120);
            $table->text('description_uz')->nullable();
            $table->text('description_ru')->nullable();
            $table->integer('sort_order')->default(0);
            $table->boolean('is_active')->default(true);
            $table->timestampTz('archived_at')->nullable();
            $table->uuid('created_by_user_id');
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->index(['is_active', 'sort_order']);
        });

        Schema::table('categories', function (Blueprint $table): void {
            $table->foreign('created_by_user_id')
                ->references('id')
                ->on('users')
                ->restrictOnDelete();
        });

        $this->check('categories_name_uz_not_blank_check', 'length(btrim(name_uz)) > 0');
        $this->check('categories_name_ru_not_blank_check', 'length(btrim(name_ru)) > 0');
        $this->check('categories_archived_inactive_check', 'archived_at is null or is_active = false');

        // Case-insensitive search in either language. The expression must match
        // the one the query uses, or PostgreSQL will not reach for the index.
        DB::statement('create index categories_name_uz_lower_index on categories (lower(name_uz))');
        DB::statement('create index categories_name_ru_lower_index on categories (lower(name_ru))');
    }

    public function down(): void
    {
        Schema::dropIfExists('categories');
    }

    private function check(string $name, string $expression): void
    {
        DB::statement("alter table categories add constraint {$name} check ({$expression})");
    }
};
