<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `orders`, as `docs/08-database.md` Section 13 names it.
 *
 * Every column a later wave fills is created now (`tasks/WAVE_2.md`, W2-1), so
 * no migration has to reshape the table once it holds orders. The snapshots are
 * what the order promised when it was placed (`BR-CORE-004`): nothing here
 * refers back to the live catalog, address or settings for a price or a fee.
 *
 * The order number comes from a sequence that starts at 1001 (`DL-37` (2)); it
 * is unique and sequential but not gapless, which `BR-ORDER-005` allows.
 *
 * The checks hold what a state implies about the columns, so a buggy action
 * cannot store, say, a completed order without its final amounts, or a
 * cancelled one without its reason.
 */
return new class extends Migration
{
    /** @var list<string> */
    private const STATUSES = [
        'new', 'shopping_assigned', 'shopping', 'final_payment_pending', 'ready_for_delivery',
        'delivery_assigned', 'on_the_way', 'completed', 'cancelled',
    ];

    /** The states an order reaches only after shopping completed. */
    private const AFTER_SHOPPING = ['final_payment_pending', 'ready_for_delivery', 'delivery_assigned', 'on_the_way', 'completed'];

    /** @var list<string> */
    private const CANCELLATION_REASONS = [
        'customer_cancelled', 'cancellation_request_approved', 'unpaid_online',
        'no_items_purchased', 'delivery_failed', 'system',
    ];

    private const PHONE_PATTERN = '^[+]998[0-9]{9}$';

    public function up(): void
    {
        DB::statement('create sequence orders_order_number_seq start with 1001');

        Schema::create('orders', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->bigInteger('order_number')->default(DB::raw("nextval('orders_order_number_seq')"))->unique();
            $table->uuid('customer_id');
            $table->uuid('source_cart_id')->unique();
            $table->uuid('source_address_id');
            $table->string('status', 32)->default('new');
            $table->string('payment_method', 16);
            $table->string('delivery_time_note', 160)->nullable();

            $table->string('recipient_name_snapshot', 120);
            $table->string('recipient_phone_snapshot', 20);
            $table->decimal('latitude_snapshot', 9, 6);
            $table->decimal('longitude_snapshot', 10, 6);
            $table->string('street_snapshot', 160);
            $table->string('house_snapshot', 40);
            $table->string('apartment_snapshot', 40)->nullable();
            $table->string('landmark_snapshot', 160)->nullable();
            $table->string('delivery_note_snapshot', 300)->nullable();

            $table->decimal('markup_percent_snapshot', 5, 2);
            $table->decimal('price_tolerance_percent_snapshot', 5, 2);
            $table->string('service_fee_mode_snapshot', 16);
            $table->bigInteger('service_fee_fixed_uzs_snapshot')->nullable();
            $table->decimal('service_fee_percent_snapshot', 5, 2)->nullable();
            $table->bigInteger('delivery_fee_uzs_snapshot');
            $table->integer('delivery_delay_threshold_minutes_snapshot');

            $table->bigInteger('final_merchandise_subtotal_uzs')->nullable();
            $table->bigInteger('final_service_fee_uzs')->nullable();
            $table->bigInteger('final_total_uzs')->nullable();

            $table->timestampTz('shopping_started_at')->nullable();
            $table->timestampTz('shopping_completed_at')->nullable();
            $table->timestampTz('ready_for_delivery_at')->nullable();
            $table->timestampTz('on_the_way_at')->nullable();
            $table->timestampTz('completed_at')->nullable();
            $table->timestampTz('cancelled_at')->nullable();
            $table->string('cancellation_reason_code', 40)->nullable();

            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->index(['customer_id', 'created_at']);
            $table->index(['status', 'created_at']);
            $table->index(['status', 'updated_at']);
            $table->index('completed_at');
            $table->index('cancelled_at');
        });

        DB::statement('alter sequence orders_order_number_seq owned by orders.order_number');

        Schema::table('orders', function (Blueprint $table): void {
            $table->foreign('customer_id')->references('id')->on('users')->restrictOnDelete();
            $table->foreign('source_cart_id')->references('id')->on('carts')->restrictOnDelete();
            $table->foreign('source_address_id')->references('id')->on('customer_addresses')->restrictOnDelete();
        });

        $this->check('orders_status_check', sprintf('status in (%s)', $this->quoted(self::STATUSES)));
        $this->check('orders_payment_method_check', "payment_method in ('cash', 'online')");
        $this->check('orders_service_fee_mode_check', "service_fee_mode_snapshot in ('fixed', 'percentage')");
        $this->check(
            'orders_service_fee_value_by_mode_check',
            "(service_fee_mode_snapshot = 'fixed' and service_fee_fixed_uzs_snapshot is not null and service_fee_percent_snapshot is null)"
            ." or (service_fee_mode_snapshot = 'percentage' and service_fee_percent_snapshot is not null and service_fee_fixed_uzs_snapshot is null)"
        );
        $this->check(
            'orders_amounts_not_negative_check',
            'markup_percent_snapshot >= 0 and price_tolerance_percent_snapshot >= 0 and delivery_fee_uzs_snapshot >= 0'
            .' and (service_fee_fixed_uzs_snapshot is null or service_fee_fixed_uzs_snapshot >= 0)'
            .' and (service_fee_percent_snapshot is null or service_fee_percent_snapshot >= 0)'
        );
        $this->check('orders_delay_threshold_check', 'delivery_delay_threshold_minutes_snapshot > 0');
        $this->check('orders_latitude_range_check', 'latitude_snapshot between -90 and 90');
        $this->check('orders_longitude_range_check', 'longitude_snapshot between -180 and 180');
        $this->check('orders_street_not_blank_check', 'length(btrim(street_snapshot)) > 0');
        $this->check('orders_house_not_blank_check', 'length(btrim(house_snapshot)) > 0');
        $this->check('orders_recipient_name_not_blank_check', 'length(btrim(recipient_name_snapshot)) > 0');
        $this->check('orders_recipient_phone_format_check', sprintf("recipient_phone_snapshot ~ '%s'", self::PHONE_PATTERN));

        // BR-MONEY-006, held where the amounts are stored: all three or none,
        // and the total is the sum. The second branch names its nulls because
        // a comparison with a null is null, and a check passes on null.
        $this->check(
            'orders_final_amounts_check',
            '(final_merchandise_subtotal_uzs is null and final_service_fee_uzs is null and final_total_uzs is null)'
            .' or (final_merchandise_subtotal_uzs is not null and final_service_fee_uzs is not null and final_total_uzs is not null'
            .' and final_merchandise_subtotal_uzs >= 0 and final_service_fee_uzs >= 0'
            .' and final_total_uzs = final_merchandise_subtotal_uzs + final_service_fee_uzs + delivery_fee_uzs_snapshot)'
        );
        $this->check(
            'orders_after_shopping_state_check',
            sprintf(
                'status not in (%s) or (shopping_completed_at is not null and final_total_uzs is not null)',
                $this->quoted(self::AFTER_SHOPPING)
            )
        );
        $this->check(
            'orders_shopping_started_check',
            "status in ('new', 'shopping_assigned', 'cancelled') or shopping_started_at is not null"
        );
        $this->check(
            'orders_ready_for_delivery_check',
            "status not in ('ready_for_delivery', 'delivery_assigned', 'on_the_way', 'completed') or ready_for_delivery_at is not null"
        );
        $this->check('orders_on_the_way_check', "status not in ('on_the_way', 'completed') or on_the_way_at is not null");
        $this->check('orders_completed_check', "(status = 'completed') = (completed_at is not null)");
        $this->check(
            'orders_cancelled_check',
            "(status = 'cancelled') = (cancelled_at is not null) and (status = 'cancelled') = (cancellation_reason_code is not null)"
        );
        $this->check(
            'orders_cancellation_reason_check',
            sprintf('cancellation_reason_code is null or cancellation_reason_code in (%s)', $this->quoted(self::CANCELLATION_REASONS))
        );
    }

    public function down(): void
    {
        Schema::dropIfExists('orders');
        DB::statement('drop sequence if exists orders_order_number_seq');
    }

    private function check(string $name, string $expression): void
    {
        DB::statement("alter table orders add constraint {$name} check ({$expression})");
    }

    /**
     * @param  list<string>  $values
     */
    private function quoted(array $values): string
    {
        return implode(', ', array_map(static fn (string $value): string => "'{$value}'", $values));
    }
};
