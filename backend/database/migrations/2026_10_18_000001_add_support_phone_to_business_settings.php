<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `business_settings.support_phone`, the number the Customer calls for help
 * (`docs/08-database.md` Section 11, `DL-91` (2)): `+998` and nine digits, or
 * unset.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('business_settings', function (Blueprint $table): void {
            $table->string('support_phone', 13)->nullable();
        });

        $this->check('business_settings_support_phone_check', "support_phone is null or support_phone ~ '^\+998[0-9]{9}$'");
    }

    public function down(): void
    {
        DB::statement('alter table business_settings drop constraint if exists business_settings_support_phone_check');

        Schema::table('business_settings', function (Blueprint $table): void {
            $table->dropColumn('support_phone');
        });
    }

    private function check(string $name, string $expression): void
    {
        DB::statement("alter table business_settings add constraint {$name} check ({$expression})");
    }
};
