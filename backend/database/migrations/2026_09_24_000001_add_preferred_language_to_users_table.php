<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `users.preferred_language`, per `docs/08-database.md` Section 3.
 *
 * The client chooses the interface language and reports it; the backend uses
 * it only to pick the language of push texts. Uzbek is the default because the
 * server never negotiates a language and a Customer who never reported one
 * still needs push texts in some language.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::table('users', function (Blueprint $table): void {
            $table->string('preferred_language', 2)->default('uz');
        });

        DB::statement(
            "alter table users add constraint users_preferred_language_check check (preferred_language in ('uz', 'ru'))"
        );
    }

    public function down(): void
    {
        DB::statement('alter table users drop constraint users_preferred_language_check');

        Schema::table('users', function (Blueprint $table): void {
            $table->dropColumn('preferred_language');
        });
    }
};
