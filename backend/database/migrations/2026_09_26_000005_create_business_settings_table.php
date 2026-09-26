<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `business_settings`, as `docs/08-database.md` Section 11 names it: one row,
 * `id = 1`, holding every value of `BR-SET-001`.
 *
 * The row is inserted here (`DL-17`), so the application reads a row that is
 * always there and never has to create one on the fly. The columns Admin has
 * to configure — fees, minimum order, working hours, service area — start as
 * null; the three that have a documented default start at it. Checkout is
 * blocked while any value it needs is null (`BR-SET-002`), which is the
 * application's rule, not this table's.
 *
 * The service-fee mode names which of its two values applies; the check keeps
 * the other one null so a switch of mode can never leave a stale value behind
 * that a later reader mistakes for the active one.
 */
return new class extends Migration
{
    /** @var list<string> */
    private const SERVICE_FEE_MODES = ['fixed', 'percentage'];

    public function up(): void
    {
        Schema::create('business_settings', function (Blueprint $table): void {
            $table->smallInteger('id')->primary();
            $table->decimal('markup_percent', 5, 2)->default(0);
            $table->string('service_fee_mode', 16)->default('fixed');
            $table->bigInteger('service_fee_fixed_uzs')->nullable();
            $table->decimal('service_fee_percent', 5, 2)->nullable();
            $table->bigInteger('delivery_fee_uzs')->nullable();
            $table->bigInteger('minimum_order_uzs')->nullable();
            $table->decimal('price_tolerance_percent', 5, 2)->default(15);
            $table->time('opens_at')->nullable();
            $table->time('closes_at')->nullable();
            $table->decimal('service_centre_latitude', 9, 6)->nullable();
            $table->decimal('service_centre_longitude', 10, 6)->nullable();
            $table->decimal('service_radius_km', 6, 2)->nullable();
            $table->integer('delivery_delay_threshold_minutes')->default(60);
            $table->uuid('updated_by_user_id')->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');
        });

        Schema::table('business_settings', function (Blueprint $table): void {
            $table->foreign('updated_by_user_id')
                ->references('id')
                ->on('users')
                ->restrictOnDelete();
        });

        $this->check('business_settings_singleton_check', 'id = 1');
        $this->check('business_settings_markup_percent_check', 'markup_percent >= 0');
        $this->check(
            'business_settings_service_fee_mode_check',
            sprintf('service_fee_mode in (%s)', implode(', ', array_map(
                static fn (string $value): string => "'{$value}'",
                self::SERVICE_FEE_MODES
            )))
        );
        $this->check(
            'business_settings_service_fee_value_by_mode_check',
            "(service_fee_mode = 'fixed' and service_fee_percent is null)
                or (service_fee_mode = 'percentage' and service_fee_fixed_uzs is null)"
        );
        $this->check('business_settings_service_fee_fixed_check', 'service_fee_fixed_uzs is null or service_fee_fixed_uzs >= 0');
        $this->check('business_settings_service_fee_percent_check', 'service_fee_percent is null or service_fee_percent >= 0');
        $this->check('business_settings_delivery_fee_check', 'delivery_fee_uzs is null or delivery_fee_uzs >= 0');
        $this->check('business_settings_minimum_order_check', 'minimum_order_uzs is null or minimum_order_uzs >= 0');
        $this->check('business_settings_price_tolerance_check', 'price_tolerance_percent >= 0');
        $this->check('business_settings_working_hours_pair_check', '(opens_at is null) = (closes_at is null)');
        $this->check(
            'business_settings_service_centre_latitude_check',
            'service_centre_latitude is null or service_centre_latitude between -90 and 90'
        );
        $this->check(
            'business_settings_service_centre_longitude_check',
            'service_centre_longitude is null or service_centre_longitude between -180 and 180'
        );
        $this->check('business_settings_service_radius_check', 'service_radius_km is null or service_radius_km > 0');
        $this->check('business_settings_delay_threshold_check', 'delivery_delay_threshold_minutes > 0');

        DB::table('business_settings')->insert([
            'id' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    public function down(): void
    {
        Schema::dropIfExists('business_settings');
    }

    private function check(string $name, string $expression): void
    {
        DB::statement("alter table business_settings add constraint {$name} check ({$expression})");
    }
};
