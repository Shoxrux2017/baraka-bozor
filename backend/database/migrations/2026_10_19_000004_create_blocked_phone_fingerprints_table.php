<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `blocked_phone_fingerprints` (`docs/08-database.md` Section 35, `DL-95`): the
 * one-way fingerprint of the phone of a blocked Customer whose account was
 * erased, so that the number cannot sign up again. There is no phone column,
 * ever; the fingerprint is the primary key.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('blocked_phone_fingerprints', function (Blueprint $table): void {
            $table->char('fingerprint', 64)->primary();
            $table->uuid('erased_user_id');
            $table->uuid('created_by_user_id');
            $table->timestampTz('created_at');
        });

        Schema::table('blocked_phone_fingerprints', function (Blueprint $table): void {
            $table->foreign('erased_user_id')->references('id')->on('users')->restrictOnDelete();
            $table->foreign('created_by_user_id')->references('id')->on('users')->restrictOnDelete();
        });

        $this->check('blocked_phone_fingerprints_fingerprint_check', "fingerprint ~ '^[0-9a-f]{64}$'");
    }

    public function down(): void
    {
        Schema::dropIfExists('blocked_phone_fingerprints');
    }

    private function check(string $name, string $expression): void
    {
        DB::statement("alter table blocked_phone_fingerprints add constraint {$name} check ({$expression})");
    }
};
