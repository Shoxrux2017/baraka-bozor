<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `customer_addresses`, as `docs/08-database.md` Section 5 names it.
 *
 * The shape and the invariants a database can hold: coordinate ranges, a
 * non-empty street and house, one owner. Whether the point lies inside the
 * service area is application logic against `business_settings` (`BR-AREA-001`),
 * because the centre and the radius are settings Admin may change, and a
 * `CHECK` cannot read another table.
 *
 * There is no hard delete of an address: `DELETE` on the API deactivates
 * (`DL-17`), and the foreign key from a future order restricts deletion anyway.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('customer_addresses', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->uuid('customer_id');
            $table->string('label', 60)->nullable();
            $table->decimal('latitude', 9, 6);
            $table->decimal('longitude', 10, 6);
            $table->string('street', 160);
            $table->string('house', 40);
            $table->string('apartment', 40)->nullable();
            $table->string('landmark', 160)->nullable();
            $table->string('delivery_note', 300)->nullable();
            $table->boolean('is_active')->default(true);
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->index(['customer_id', 'is_active']);
        });

        Schema::table('customer_addresses', function (Blueprint $table): void {
            $table->foreign('customer_id')
                ->references('id')
                ->on('users')
                ->restrictOnDelete();
        });

        $this->check('customer_addresses_latitude_range_check', 'latitude between -90 and 90');
        $this->check('customer_addresses_longitude_range_check', 'longitude between -180 and 180');
        $this->check('customer_addresses_street_not_blank_check', 'length(btrim(street)) > 0');
        $this->check('customer_addresses_house_not_blank_check', 'length(btrim(house)) > 0');
    }

    public function down(): void
    {
        Schema::dropIfExists('customer_addresses');
    }

    private function check(string $name, string $expression): void
    {
        DB::statement("alter table customer_addresses add constraint {$name} check ({$expression})");
    }
};
