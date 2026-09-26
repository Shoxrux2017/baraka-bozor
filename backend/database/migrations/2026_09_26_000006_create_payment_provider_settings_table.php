<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `payment_provider_settings`, as `docs/08-database.md` Section 12 names it:
 * one row per provider `DL-2` 3.3 names, keyed by the provider itself, holding
 * only whether new online payments may use it (`BR-SET-004`). No secrets: the
 * merchant credentials are backend configuration and never reach a table an
 * API reads.
 *
 * The four rows are inserted here, disabled (`DL-17`), so Admin enables a
 * provider rather than creating it, and the list the panel shows is fixed.
 */
return new class extends Migration
{
    /** @var list<string> */
    private const PROVIDERS = ['payme', 'click', 'paynet', 'xazna'];

    public function up(): void
    {
        Schema::create('payment_provider_settings', function (Blueprint $table): void {
            $table->string('provider', 16)->primary();
            $table->boolean('is_enabled')->default(false);
            $table->uuid('updated_by_user_id')->nullable();
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');
        });

        Schema::table('payment_provider_settings', function (Blueprint $table): void {
            $table->foreign('updated_by_user_id')
                ->references('id')
                ->on('users')
                ->restrictOnDelete();
        });

        DB::statement(sprintf(
            'alter table payment_provider_settings add constraint payment_provider_settings_provider_check check (provider in (%s))',
            implode(', ', array_map(static fn (string $value): string => "'{$value}'", self::PROVIDERS))
        ));

        DB::table('payment_provider_settings')->insert(array_map(
            static fn (string $provider): array => [
                'provider' => $provider,
                'is_enabled' => false,
                'created_at' => now(),
                'updated_at' => now(),
            ],
            self::PROVIDERS
        ));
    }

    public function down(): void
    {
        Schema::dropIfExists('payment_provider_settings');
    }
};
