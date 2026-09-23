<?php

declare(strict_types=1);

namespace Tests\Feature\Identity;

use Illuminate\Database\QueryException;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * The identity invariants, asserted against PostgreSQL rather than against any
 * model, request or service.
 *
 * Every insert here goes through the query builder, so no Eloquent cast, mutator
 * or validation rule is in the path. That is the point: `08` Section 3 says the
 * constraint is enforced by the database, and a rule that lives only in a form
 * request is bypassed by a console command, a seeder, a future job or a psql
 * session. If one of these tests fails, the database would accept a row the
 * business rules forbid.
 *
 * Each rejection is matched against the constraint's own name, not merely
 * against "some error". Without that, a typo in a column name would raise a
 * different error, the test would still pass, and the invariant would be
 * unguarded.
 */
final class UsersTableConstraintsTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    /** The roles `BR-ROLE-001` approves, and no others. */
    private const ROLES = ['customer', 'shopper', 'courier', 'operator', 'admin', 'manager'];

    /**
     * A Staff row that violates nothing, for a test to bend one field of.
     *
     * The password is not a real hash: nothing here verifies one, and a
     * committed string shaped like a credential is worth avoiding.
     *
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function row(array $overrides = []): array
    {
        return array_merge([
            'id' => (string) Str::uuid(),
            'role' => 'admin',
            'phone' => '+998901234567',
            'full_name' => null,
            'password' => 'bcrypt-hash-placeholder',
            'status' => 'active',
            'must_change_password' => false,
            'password_changed_at' => null,
            'last_login_at' => null,
            'blocked_at' => null,
            'created_by_user_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ], $overrides);
    }

    /**
     * A Customer row that violates nothing: no password and no first-login gate.
     *
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function customerRow(array $overrides = []): array
    {
        return $this->row(array_merge([
            'role' => 'customer',
            'password' => null,
            'must_change_password' => false,
        ], $overrides));
    }

    /**
     * @param  array<string, mixed>  $row
     */
    private function insert(array $row): void
    {
        DB::table('users')->insert($row);
    }

    public function test_every_approved_role_is_accepted(): void
    {
        foreach (self::ROLES as $index => $role) {
            // A distinct phone per role: five of the six are Staff, and the
            // active-Staff index would reject the second of them on one phone
            // for a reason that has nothing to do with the role check.
            $phone = sprintf('+9989012345%02d', $index);

            $this->insert($role === 'customer'
                ? $this->customerRow(['phone' => $phone])
                : $this->row(['role' => $role, 'phone' => $phone]));
        }

        $this->assertSame(6, DB::table('users')->count());
    }

    public function test_a_seventh_role_is_rejected(): void
    {
        $this->assertRejectedBy(
            'users',
            'users_role_check',
            $this->row(['role' => 'superadmin']),
            'BR-ROLE-001 approves exactly six roles.'
        );
    }

    public function test_a_status_outside_the_two_approved_values_is_rejected(): void
    {
        $this->assertRejectedBy(
            'users',
            'users_status_check',
            $this->row(['status' => 'suspended']),
            '08 Section 3 approves active and blocked only.'
        );
    }

    public function test_a_customer_with_a_password_is_rejected(): void
    {
        $this->assertRejectedBy(
            'users',
            'users_password_by_family_check',
            $this->customerRow(['password' => 'bcrypt-hash-placeholder']),
            'Customers authenticate by OTP and hold no password.'
        );
    }

    public function test_a_staff_account_without_a_password_is_rejected(): void
    {
        $this->assertRejectedBy(
            'users',
            'users_password_by_family_check',
            $this->row(['password' => null]),
            'Staff authenticate by phone and password.'
        );
    }

    public function test_a_customer_carrying_the_first_login_gate_is_rejected(): void
    {
        $this->assertRejectedBy(
            'users',
            'users_customer_no_password_gate_check',
            $this->customerRow(['must_change_password' => true]),
            'A Customer holds no password, so a forced password change could never be '
            .'satisfied and would lock the account out permanently.'
        );
    }

    public function test_a_blocked_account_without_a_blocked_instant_is_rejected(): void
    {
        $this->assertRejectedBy(
            'users',
            'users_blocked_at_check',
            $this->row(['status' => 'blocked', 'blocked_at' => null]),
            'A blocked account with no blocked_at cannot be audited or explained.'
        );
    }

    public function test_a_phone_outside_the_locked_format_is_rejected(): void
    {
        $rejected = [
            '998901234567' => 'no leading plus',
            '+99890123456' => 'eight digits after the country code',
            '+9989012345678' => 'ten digits after the country code',
            '+7 901 234 56 78' => 'another country code, and spaces',
            '+99890123456a' => 'a letter',
            '' => 'nothing at all',
        ];

        foreach ($rejected as $phone => $why) {
            $this->assertRejectedBy(
                'users',
                'users_phone_format_check',
                $this->row(['phone' => (string) $phone]),
                "A phone carrying {$why} is not the E.164 Uzbek number 08 Section 3 fixes."
            );
        }
    }

    public function test_a_second_active_customer_on_one_phone_is_rejected(): void
    {
        $this->insert($this->customerRow());

        $this->assertRejectedBy(
            'users',
            'users_phone_active_customer_unique',
            $this->customerRow(),
            '02 Section 3 allows at most one active Customer account per phone.'
        );
    }

    public function test_a_second_active_staff_account_on_one_phone_is_rejected(): void
    {
        $this->insert($this->row(['role' => 'operator']));

        $this->assertRejectedBy(
            'users',
            'users_phone_active_staff_unique',
            // A different Staff role on the same phone: the index is keyed on
            // `role <> 'customer'`, not on one role, so changing the role must
            // not let a second active Staff account through.
            $this->row(['role' => 'courier']),
            '02 Section 3 allows at most one active Staff account per phone.'
        );
    }

    public function test_an_active_customer_and_an_active_staff_account_may_share_one_phone(): void
    {
        $this->insert($this->customerRow());
        $this->insert($this->row());

        // The case a plain unique index on `phone` would have broken: one person
        // who both shops on the platform and works for it. 02 Section 3 requires
        // both accounts to be able to exist at once.
        $this->assertSame(2, DB::table('users')->where('phone', '+998901234567')->count());
    }

    public function test_a_blocked_and_an_active_account_of_one_family_may_share_one_phone(): void
    {
        $this->insert($this->row(['role' => 'shopper', 'status' => 'blocked', 'blocked_at' => now()]));
        $this->insert($this->row(['role' => 'courier']));

        // This is what makes BR-ROLE-002 possible: a Staff member's role changes
        // by blocking the old account and creating a new one, and for as long as
        // the history is kept both exist on the same phone.
        $this->assertSame(2, DB::table('users')->where('phone', '+998901234567')->count());
    }

    public function test_the_creator_reference_must_point_at_a_real_user(): void
    {
        $this->assertRejectedBy(
            'users',
            'users_created_by_user_id_foreign',
            $this->row(['created_by_user_id' => (string) Str::uuid()]),
            'A creator that does not exist makes the audit trail a lie.'
        );
    }

    public function test_a_user_who_created_another_cannot_be_hard_deleted(): void
    {
        $creator = $this->row();
        $this->insert($creator);
        $this->insert($this->row([
            'role' => 'operator',
            'phone' => '+998901234568',
            'created_by_user_id' => $creator['id'],
        ]));

        $this->expectException(QueryException::class);

        // ON DELETE RESTRICT, not CASCADE and not SET NULL. 08 Section 3 forbids
        // hard-deleting historical users, and a cascade here would quietly delete
        // every account an Admin ever created along with the Admin.
        DB::table('users')->where('id', $creator['id'])->delete();
    }

    public function test_the_locked_indexes_exist(): void
    {
        $indexes = $this->indexesOn('users');

        foreach ([
            'users_phone_active_customer_unique',
            'users_phone_active_staff_unique',
            'users_role_status_index',
            'users_full_name_lower_index',
        ] as $expected) {
            $this->assertArrayHasKey(
                $expected,
                $indexes,
                sprintf('Index %s is missing; 08 Section 3 names it.', $expected)
            );
        }

        // The definitions, not only the names. An index that kept its name while
        // losing `UNIQUE` or losing its `WHERE` would pass a name check and quietly
        // stop enforcing anything — and the partial predicates are the whole reason
        // these two indexes exist instead of one plain unique on `phone`.
        $this->assertMatchesRegularExpression(
            "/CREATE UNIQUE INDEX .*\(phone\) WHERE .*'active'.*AND.*'customer'/s",
            $indexes['users_phone_active_customer_unique']
        );

        $this->assertMatchesRegularExpression(
            "/CREATE UNIQUE INDEX .*\(phone\) WHERE .*'active'.*AND.*<> *'customer'/s",
            $indexes['users_phone_active_staff_unique']
        );

        $this->assertStringContainsString('lower(', $indexes['users_full_name_lower_index']);
    }

    public function test_a_blocked_and_an_active_customer_may_share_one_phone(): void
    {
        // The Customer half of the same rule. Tested separately because the two
        // families have separate indexes with separate predicates, and one of them
        // being right says nothing about the other.
        $this->insert($this->customerRow(['status' => 'blocked', 'blocked_at' => now()]));
        $this->insert($this->customerRow());

        $this->assertSame(2, DB::table('users')->where('phone', '+998901234567')->count());
    }
}
