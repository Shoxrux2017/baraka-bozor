<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * `customer_otp_challenges`, as `docs/08-database.md` Section 4 names it.
 *
 * The table lives in the wave's schema task rather than in the task that uses
 * it, because `backend/database/migrations/**` belongs to the `wave-owner` track
 * in `tasks/OWNERSHIP.md` — the `auth-backend` track that builds Customer OTP
 * login owns no path it could put a migration in.
 *
 * Only the shape and the invariants are settled here. How a code is generated,
 * hashed, verified, expired or rate-limited is `S01-BE-004`'s to decide, and
 * `code_hash` deliberately says nothing about the algorithm. The one thing `08`
 * Section 4 does fix is that no plaintext OTP is ever stored, which is why there
 * is no column that could hold one.
 *
 * There is no `updated_at`. A challenge is created once and afterwards only
 * closed, by `consumed_at` or `invalidated_at`; a generic "last touched" instant
 * would carry no information those two do not.
 */
return new class extends Migration
{
    /** The purposes `08` Section 4 approves. A second one is a product decision. */
    private const PURPOSES = ['customer_login'];

    public function up(): void
    {
        Schema::create('customer_otp_challenges', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('phone', 20);
            $table->string('purpose', 24);
            $table->string('code_hash', 255);
            $table->smallInteger('failed_attempts')->default(0);
            $table->timestampTz('expires_at');
            $table->timestampTz('consumed_at')->nullable();
            $table->timestampTz('invalidated_at')->nullable();
            $table->timestampTz('created_at');

            // Finding the live challenge for a phone, newest first.
            $table->index(['phone', 'created_at']);

            // Sweeping expired rows, which is a scan over this column alone.
            $table->index('expires_at');
        });

        // The same rule as `users.phone`, repeated rather than shared: a
        // challenge is looked up by phone, so a number stored in a second shape
        // here would simply never match the account it belongs to. Migrations are
        // a historical record and do not import each other, so the duplication is
        // deliberate.
        $this->check('customer_otp_challenges_phone_format_check', "phone ~ '^\\+998[0-9]{9}\$'");

        $this->check(
            'customer_otp_challenges_purpose_check',
            sprintf(
                'purpose in (%s)',
                implode(', ', array_map(static fn (string $p): string => "'{$p}'", self::PURPOSES))
            )
        );

        // A negative count would silently widen whatever attempt limit
        // `S01-BE-004` sets, which is the one thing standing between an OTP and
        // brute force.
        $this->check('customer_otp_challenges_failed_attempts_check', 'failed_attempts >= 0');
    }

    public function down(): void
    {
        Schema::dropIfExists('customer_otp_challenges');
    }

    /**
     * Add a named `CHECK` constraint.
     *
     * Named rather than left to PostgreSQL, which would generate something like
     * `customer_otp_challenges_check1` — a name that says nothing about the rule
     * and changes when an unrelated constraint is added.
     */
    private function check(string $name, string $expression): void
    {
        DB::statement("alter table customer_otp_challenges add constraint {$name} check ({$expression})");
    }
};
