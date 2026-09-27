<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `carts`, as `docs/08-database.md` Section 9 names it.
 *
 * A cart is `active` until an order converts it (`BR-CHK-008`); `abandoned` was
 * dropped (`DL-3` S-14). At most one active cart per Customer is a database
 * rule (`BR-CART-001`), so two first accesses at once cannot both create one.
 */
return new class extends Migration
{
    /** @var list<string> */
    private const STATUSES = ['active', 'converted'];

    public function up(): void
    {
        Schema::create('carts', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('customer_id');
            $table->string('status', 16)->default('active');
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');
        });

        Schema::table('carts', function (Blueprint $table): void {
            $table->foreign('customer_id')
                ->references('id')
                ->on('users')
                ->restrictOnDelete();
        });

        DB::statement(sprintf(
            'alter table carts add constraint carts_status_check check (status in (%s))',
            implode(', ', array_map(static fn (string $value): string => "'{$value}'", self::STATUSES))
        ));

        DB::statement("create unique index carts_customer_active_unique on carts (customer_id) where status = 'active'");
    }

    public function down(): void
    {
        Schema::dropIfExists('carts');
    }
};
