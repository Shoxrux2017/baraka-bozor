<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * A Customer account can be erased (`BR-ROLE-013`, `DL-94` item 4).
 *
 * The user row stays — orders, payments and history reference it — but becomes
 * `deleted` with no phone. The order snapshots of the person (recipient, point,
 * address) become nullable, and only an order marked `customer_erased_at` may
 * lack them, so a buggy action cannot store an ordinary order without its
 * address. The address an order was placed to is erased with the Customer's
 * addresses, so the pointer to it is set to null by the database.
 */
return new class extends Migration
{
    private const SNAPSHOTS = [
        'recipient_name_snapshot',
        'recipient_phone_snapshot',
        'latitude_snapshot',
        'longitude_snapshot',
        'street_snapshot',
        'house_snapshot',
    ];

    public function up(): void
    {
        DB::statement('alter table users alter column phone drop not null');

        Schema::table('users', function (Blueprint $table): void {
            $table->timestampTz('deleted_at')->nullable();
            $table->uuid('deleted_by_user_id')->nullable();
            $table->foreign('deleted_by_user_id')->references('id')->on('users')->restrictOnDelete();
        });

        DB::statement('alter table users drop constraint users_status_check');
        $this->check('users', 'users_status_check', "status in ('active', 'blocked', 'deleted')");
        $this->check('users', 'users_phone_present_check', "phone is not null or status = 'deleted'");
        $this->check(
            'users',
            'users_deleted_check',
            "(status = 'deleted') = (deleted_at is not null) and (status = 'deleted' or deleted_by_user_id is null)"
        );

        foreach ([...self::SNAPSHOTS, 'source_address_id'] as $column) {
            DB::statement("alter table orders alter column {$column} drop not null");
        }

        Schema::table('orders', function (Blueprint $table): void {
            $table->timestampTz('customer_erased_at')->nullable();
        });

        DB::statement('alter table orders drop constraint orders_source_address_id_foreign');
        DB::statement(
            'alter table orders add constraint orders_source_address_id_foreign'
            .' foreign key (source_address_id) references customer_addresses (id) on delete set null'
        );
        $this->check(
            'orders',
            'orders_personal_snapshots_check',
            'customer_erased_at is not null or ('.implode(' is not null and ', self::SNAPSHOTS).' is not null)'
        );

        DB::statement('alter table order_cancellation_requests alter column reason drop not null');

        // History stays append-only. The one exception is the erasure of a
        // Customer: inside a transaction that sets `app.customer_erasure`, a
        // row may change its `note` and `details` and nothing else.
        DB::unprepared(<<<'SQL'
            create or replace function order_history_append_only() returns trigger language plpgsql as $$
            begin
                if tg_op = 'UPDATE'
                    and current_setting('app.customer_erasure', true) = 'on'
                    and (to_jsonb(new) - 'note' - 'details') = (to_jsonb(old) - 'note' - 'details') then
                    return new;
                end if;

                raise exception 'order_history is append-only';
            end;
            $$;
            SQL);
    }

    public function down(): void
    {
        DB::unprepared(<<<'SQL'
            create or replace function order_history_append_only() returns trigger language plpgsql as $$
            begin
                raise exception 'order_history is append-only';
            end;
            $$;
            SQL);

        // Erased data cannot come back: the columns are made required again
        // only when no erased account or order exists.
        DB::statement('alter table order_cancellation_requests alter column reason set not null');
        DB::statement('alter table orders drop constraint orders_personal_snapshots_check');
        DB::statement('alter table orders drop constraint orders_source_address_id_foreign');
        DB::statement(
            'alter table orders add constraint orders_source_address_id_foreign'
            .' foreign key (source_address_id) references customer_addresses (id) on delete restrict'
        );
        DB::statement('alter table orders alter column source_address_id set not null');

        foreach (self::SNAPSHOTS as $column) {
            DB::statement("alter table orders alter column {$column} set not null");
        }

        Schema::table('orders', function (Blueprint $table): void {
            $table->dropColumn('customer_erased_at');
        });

        DB::statement('alter table users drop constraint users_deleted_check');
        DB::statement('alter table users drop constraint users_phone_present_check');
        DB::statement('alter table users drop constraint users_status_check');
        $this->check('users', 'users_status_check', "status in ('active', 'blocked')");

        Schema::table('users', function (Blueprint $table): void {
            $table->dropForeign(['deleted_by_user_id']);
            $table->dropColumn(['deleted_at', 'deleted_by_user_id']);
        });

        DB::statement('alter table users alter column phone set not null');
    }

    private function check(string $table, string $name, string $expression): void
    {
        DB::statement("alter table {$table} add constraint {$name} check ({$expression})");
    }
};
