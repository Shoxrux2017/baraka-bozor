<?php

declare(strict_types=1);

namespace Tests\Feature\Identity;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * The `customer_otp_challenges` table, as `docs/08-database.md` Section 4 names
 * it and the approved contract types it.
 *
 * This table is created here, with the rest of the identity schema, rather than
 * by the task that will use it. `backend/database/migrations/**` belongs to the
 * `wave-owner` track in `tasks/OWNERSHIP.md`, so the `auth-backend` track that
 * builds Customer OTP login cannot add a migration of its own without editing a
 * path it does not own. The wave model puts the wave's tables in the wave's
 * schema task for exactly this reason.
 *
 * What lives here is the shape and the invariants. How a code is generated,
 * hashed, checked, expired or rate-limited is `S01-BE-004`'s, and nothing about
 * it is decided by this table beyond the one thing `08` Section 4 does fix: no
 * plaintext OTP is ever stored.
 */
final class CustomerOtpChallengesTableTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    private const TABLE = 'customer_otp_challenges';

    /**
     * Every column `08` Section 4 names, with the type and nullability the
     * approved contract fixes.
     *
     * @return array<string, array{string, bool}>
     */
    private function expectedColumns(): array
    {
        return [
            'id' => ['uuid', false],
            'phone' => ['character varying', false],
            'purpose' => ['character varying', false],
            'code_hash' => ['character varying', false],
            'failed_attempts' => ['smallint', false],
            'expires_at' => ['timestamp with time zone', false],
            'consumed_at' => ['timestamp with time zone', true],
            'invalidated_at' => ['timestamp with time zone', true],
            'created_at' => ['timestamp with time zone', false],
        ];
    }

    /**
     * A challenge that violates nothing, for a test to bend one field of.
     *
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function row(array $overrides = []): array
    {
        return array_merge([
            'id' => (string) Str::uuid(),
            'phone' => '+998901234567',
            'purpose' => 'customer_login',
            'code_hash' => 'hash-placeholder',
            'failed_attempts' => 0,
            'expires_at' => now()->addMinutes(5),
            'consumed_at' => null,
            'invalidated_at' => null,
            'created_at' => now(),
        ], $overrides);
    }

    public function test_it_has_exactly_the_columns_the_locked_schema_names(): void
    {
        $actual = array_keys($this->columnsOf(self::TABLE));
        $expected = array_keys($this->expectedColumns());

        sort($actual);
        sort($expected);

        $this->assertSame(
            $expected,
            $actual,
            'The table does not carry exactly the columns docs/08-database.md Section 4 names.'
        );
    }

    public function test_it_carries_no_updated_at(): void
    {
        // `08` Section 4 lists `created_at` and no `updated_at`, and the absence
        // is meaningful rather than an oversight: a challenge is created once and
        // then only closed, by `consumed_at` or `invalidated_at`. A generic
        // "last touched" instant would say nothing those two do not, and
        // `timestamps()` would have added one without anyone deciding to.
        $this->assertArrayNotHasKey(
            'updated_at',
            $this->columnsOf(self::TABLE),
            'docs/08-database.md Section 4 lists created_at only. Use timestampTz(\'created_at\'), '
            .'not timestamps()/timestampsTz().'
        );
    }

    public function test_every_column_has_the_type_and_nullability_the_contract_fixes(): void
    {
        $actual = $this->columnsOf(self::TABLE);

        foreach ($this->expectedColumns() as $column => [$type, $nullable]) {
            $this->assertArrayHasKey($column, $actual, self::TABLE.".{$column} is missing.");

            $this->assertSame(
                $type,
                $actual[$column]->data_type,
                sprintf('%s.%s is %s, expected %s.', self::TABLE, $column, $actual[$column]->data_type, $type)
            );

            $this->assertSame(
                $nullable ? 'YES' : 'NO',
                $actual[$column]->is_nullable,
                sprintf('%s.%s nullability does not match the approved contract.', self::TABLE, $column)
            );
        }
    }

    public function test_every_instant_is_stored_with_a_time_zone(): void
    {
        foreach (['expires_at', 'consumed_at', 'invalidated_at', 'created_at'] as $column) {
            $this->assertSame(
                'timestamp with time zone',
                $this->columnsOf(self::TABLE)[$column]->data_type,
                sprintf(
                    '%s.%s is not timestamptz. An OTP expiry without a zone expires at whatever '
                    .'the session time zone happens to be, which is a security boundary moving '
                    .'with a connection setting.',
                    self::TABLE,
                    $column
                )
            );
        }
    }

    public function test_a_valid_challenge_is_accepted(): void
    {
        DB::table(self::TABLE)->insert($this->row());

        $this->assertSame(1, DB::table(self::TABLE)->count());
    }

    public function test_a_purpose_outside_the_approved_value_is_rejected(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'customer_otp_challenges_purpose_check',
            $this->row(['purpose' => 'password_reset']),
            '08 Section 4 approves customer_login and nothing else. A second purpose is a '
            .'product decision, not an implementation choice.'
        );
    }

    public function test_a_phone_outside_the_locked_format_is_rejected(): void
    {
        // The same rule as `users.phone`. A challenge is looked up by phone, so a
        // number stored in a second shape here would simply never be found.
        $this->assertRejectedBy(
            self::TABLE,
            'customer_otp_challenges_phone_format_check',
            $this->row(['phone' => '998901234567']),
            'A phone with no leading plus is not the E.164 Uzbek number the schema fixes.'
        );
    }

    public function test_a_negative_attempt_count_is_rejected(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'customer_otp_challenges_failed_attempts_check',
            $this->row(['failed_attempts' => -1]),
            'A negative count would silently widen an attempt limit that exists to stop brute force.'
        );
    }

    public function test_the_attempt_count_starts_at_zero_without_being_told(): void
    {
        $row = $this->row();
        unset($row['failed_attempts']);

        DB::table(self::TABLE)->insert($row);

        $this->assertSame(
            0,
            (int) DB::table(self::TABLE)->value('failed_attempts'),
            'A challenge that begins with no attempt count recorded would make the first '
            .'increment ambiguous.'
        );
    }

    public function test_the_locked_indexes_exist(): void
    {
        $indexes = array_keys($this->indexesOn(self::TABLE));

        foreach ([
            'customer_otp_challenges_phone_created_at_index',
            'customer_otp_challenges_expires_at_index',
        ] as $expected) {
            $this->assertContains(
                $expected,
                $indexes,
                sprintf('Index %s is missing; 08 Section 4 names it.', $expected)
            );
        }
    }
}
