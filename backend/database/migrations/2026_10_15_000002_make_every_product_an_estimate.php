<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

/**
 * DL-78: every product is an estimate. Lines already placed keep their
 * `price_mode_snapshot`; only the catalog changes.
 */
return new class extends Migration
{
    public function up(): void
    {
        DB::statement("update products set price_mode = 'estimate', updated_at = now() where price_mode <> 'estimate'");
        DB::statement('alter table products drop constraint products_price_mode_check');
        DB::statement("alter table products add constraint products_price_mode_check check (price_mode = 'estimate')");
    }

    public function down(): void
    {
        DB::statement('alter table products drop constraint products_price_mode_check');
        DB::statement("alter table products add constraint products_price_mode_check check (price_mode in ('fixed', 'estimate'))");
    }
};
