<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

/**
 * The `users` table, exactly as `docs/08-database.md` Section 3 locks it.
 *
 * Two things here are deliberate and easy to undo by accident.
 *
 * Every instant is `timestampTz`, never `timestamp`. On PostgreSQL Laravel's
 * `timestamp()` and `timestamps()` emit `timestamp without time zone`, which
 * drops the offset a client sent and makes the stored instant mean whatever the
 * session time zone happened to be. `08` Section 1 requires the zone.
 *
 * And the identity invariants live in the database, not only in a form request.
 * A request rule is bypassed by a console command, a seeder, a queued job or a
 * `psql` session; a `CHECK` is not. `08` Section 3 says the constraint is
 * enforced by the database, so it is.
 */
return new class extends Migration
{
    /**
     * The roles `BR-ROLE-001` approves, and no others.
     *
     * @var list<string>
     */
    private const ROLES = ['customer', 'shopper', 'courier', 'operator', 'admin', 'manager'];

    /** The account states `08` Section 3 approves. */
    private const STATUSES = ['active', 'blocked'];

    public function up(): void
    {
        Schema::create('users', function (Blueprint $table) {
            $table->uuid('id')->primary();
            $table->string('role', 24);
            $table->string('phone', 20);
            $table->string('full_name', 160)->nullable();
            $table->string('password', 255)->nullable();
            $table->string('status', 16);
            $table->boolean('must_change_password')->default(false);
            $table->timestampTz('password_changed_at')->nullable();
            $table->timestampTz('last_login_at')->nullable();
            $table->timestampTz('blocked_at')->nullable();
            $table->uuid('created_by_user_id')->nullable();

            // Spelled out rather than `timestampsTz()`, which makes both columns
            // nullable. `08` Section 3 marks them NOT NULL, and a nullable
            // `created_at` lets a row exist with no recorded creation instant.
            $table->timestampTz('created_at');
            $table->timestampTz('updated_at');

            $table->index(['role', 'status']);
        });

        // Added after the table rather than inside it. The fluent `primary()`
        // above becomes its own `alter table` statement, which Laravel appends
        // *after* the commands the closure adds explicitly — so a foreign key
        // declared in the closure runs first and PostgreSQL rejects it with
        // "there is no unique constraint matching given keys". A self-reference
        // is the one case where that ordering is visible.
        //
        // RESTRICT, not CASCADE and not SET NULL. `08` Section 3 forbids
        // hard-deleting historical users; a cascade would delete every account
        // an Admin ever created along with the Admin, and SET NULL would quietly
        // erase the audit trail instead of refusing.
        Schema::table('users', function (Blueprint $table) {
            $table->foreign('created_by_user_id')
                ->references('id')
                ->on('users')
                ->restrictOnDelete();
        });

        $this->check(
            'users_role_check',
            sprintf('role in (%s)', $this->quoted(self::ROLES))
        );

        $this->check(
            'users_status_check',
            sprintf('status in (%s)', $this->quoted(self::STATUSES))
        );

        // E.164 for Uzbekistan: a literal plus, the country code, nine digits,
        // and nothing else. Anchored at both ends — an unanchored pattern would
        // accept a valid number with anything appended to it.
        $this->check('users_phone_format_check', "phone ~ '^\\+998[0-9]{9}\$'");

        // The two account families differ in how they authenticate, and the
        // difference is structural rather than a matter of policy: a Customer
        // signs in by OTP and must hold no password, Staff sign in by phone and
        // password and must hold one.
        $this->check(
            'users_password_by_family_check',
            "(role = 'customer' and password is null) or (role <> 'customer' and password is not null)"
        );

        // A Customer has no password, so a forced password change could never be
        // satisfied. Setting the gate would lock the account out permanently.
        $this->check(
            'users_customer_no_password_gate_check',
            "role <> 'customer' or must_change_password = false"
        );

        // A blocked account with no instant cannot be audited or explained, and
        // nothing later can reconstruct when it happened.
        $this->check('users_blocked_at_check', "status <> 'blocked' or blocked_at is not null");

        // Quoted verbatim from `08` Section 3. Not a plain unique index on
        // `phone`: one person may both shop on the platform and work for it, so
        // uniqueness holds within each account family, not across the table.
        // `role` and `status` are both NOT NULL, so neither predicate can be
        // evaded by leaving a column out.
        DB::statement(
            "create unique index users_phone_active_customer_unique
                 on users (phone) where status = 'active' and role = 'customer'"
        );

        DB::statement(
            "create unique index users_phone_active_staff_unique
                 on users (phone) where status = 'active' and role <> 'customer'"
        );

        // Case-insensitive name search. The expression has to match the one a
        // query uses, or PostgreSQL will not reach for this index.
        DB::statement('create index users_full_name_lower_index on users (lower(full_name))');
    }

    public function down(): void
    {
        Schema::dropIfExists('users');
    }

    /**
     * Add a named `CHECK` constraint.
     *
     * Named explicitly rather than left to PostgreSQL, which would generate
     * something like `users_check1`. The name is what a failing test and a
     * production error log both show, and a generated one says nothing about
     * which rule was broken — and changes when an unrelated constraint is added.
     */
    private function check(string $name, string $expression): void
    {
        DB::statement("alter table users add constraint {$name} check ({$expression})");
    }

    /**
     * @param  list<string>  $values
     */
    private function quoted(array $values): string
    {
        return implode(', ', array_map(static fn (string $value): string => "'{$value}'", $values));
    }
};
