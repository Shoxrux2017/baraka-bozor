<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `legal_documents`, as `docs/08-database.md` Section 34 names it: the terms
 * of use and the privacy policy, append-only (`DL-94` item 1). The newest row
 * of a kind and language (the highest `edition`) is in force; a null `body`
 * means not published.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('legal_documents', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->string('kind', 16);
            $table->char('language', 2);
            $table->text('body')->nullable();
            $table->uuid('created_by_user_id');
            $table->timestampTz('created_at');

            $table->foreign('created_by_user_id')
                ->references('id')
                ->on('users')
                ->restrictOnDelete();
            $table->index(['kind', 'language', 'created_at']);
        });

        DB::statement('alter table legal_documents add column edition bigint generated always as identity unique');

        $this->check('legal_documents_kind_check', "kind in ('terms', 'privacy')");
        $this->check('legal_documents_language_check', "language in ('uz', 'ru')");
    }

    public function down(): void
    {
        Schema::dropIfExists('legal_documents');
    }

    private function check(string $name, string $expression): void
    {
        DB::statement("alter table legal_documents add constraint {$name} check ({$expression})");
    }
};
