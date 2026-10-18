<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `order_ratings`, as `docs/08-database.md` Section 33 names it: the
 * Customer's rating of a delivered order (`DL-90` (1), `DL-91` (4)).
 *
 * `BR-RATE-001` in the database: one rating per order (the unique
 * `order_id`). `BR-RATE-002`: 1 to 5 stars, and reasons only at 1 to 3.
 * `BR-RATE-003`: a review names its reviewer and its time together. The
 * window of seven days is the application's.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('order_ratings', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('order_id')->unique();
            $table->uuid('customer_id');
            $table->smallInteger('stars');
            $table->jsonb('reasons')->default('[]');
            $table->string('comment', 500)->nullable();
            $table->uuid('reviewed_by_user_id')->nullable();
            $table->timestampTz('reviewed_at')->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');
        });

        Schema::table('order_ratings', function (Blueprint $table): void {
            $table->foreign('order_id')->references('id')->on('orders')->restrictOnDelete();
            $table->foreign('customer_id')->references('id')->on('users')->restrictOnDelete();
            $table->foreign('reviewed_by_user_id')->references('id')->on('users')->restrictOnDelete();
        });

        $this->check('order_ratings_stars_check', 'stars between 1 and 5');
        $this->check('order_ratings_reasons_type_check', "jsonb_typeof(reasons) = 'array'");
        $this->check('order_ratings_reasons_check', "stars <= 3 or reasons = '[]'::jsonb");
        $this->check('order_ratings_reviewed_check', '(reviewed_by_user_id is null) = (reviewed_at is null)');
    }

    public function down(): void
    {
        Schema::dropIfExists('order_ratings');
    }

    private function check(string $name, string $expression): void
    {
        DB::statement("alter table order_ratings add constraint {$name} check ({$expression})");
    }
};
