<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `staff_login_steps` (`DL-77`): the single-use step a verified login code
 * hands to a Shopper or Courier, redeemed with the staff password.
 *
 * Only the hash of the step token is stored, like the hash of a login code.
 */
return new class extends Migration
{
    public function up(): void
    {
        Schema::create('staff_login_steps', function (Blueprint $table): void {
            $table->uuid('id')->primary();
            $table->foreignUuid('staff_user_id')->constrained('users')->restrictOnDelete();
            $table->char('token_hash', 64)->unique();
            $table->timestampTz('expires_at');
            $table->timestampTz('consumed_at')->nullable();
            $table->smallInteger('failed_attempts')->default(0);
            $table->timestampsTz();

            $table->index(['staff_user_id', 'consumed_at']);
        });

        DB::statement('ALTER TABLE staff_login_steps ADD CONSTRAINT staff_login_steps_failed_attempts_check CHECK (failed_attempts >= 0)');
    }

    public function down(): void
    {
        Schema::dropIfExists('staff_login_steps');
    }
};
