<?php

declare(strict_types=1);

namespace Tests\Feature\Identity;

use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;
use Laravel\Sanctum\HasApiTokens;
use Tests\TestCase;

/**
 * `User` is the one place the rest of the backend meets the identity table, so
 * what it guarantees matters more than what it merely happens to do today.
 *
 * Three of those guarantees are load-bearing and easy to lose in a refactor: a
 * role and a status arrive as enums rather than as loose strings, a password is
 * never stored or serialized in plaintext, and the fields the server is
 * authoritative over cannot be set by mass assignment.
 */
final class UserModelTest extends TestCase
{
    use RefreshDatabase;

    private function staff(array $attributes = []): User
    {
        $user = new User;

        $user->forceFill(array_merge([
            'role' => Role::Admin,
            'phone' => '+998901234567',
            'full_name' => 'Bootstrap Admin',
            'password' => 'correct horse battery staple',
            'status' => UserStatus::Active,
            'must_change_password' => false,
        ], $attributes));

        $user->save();

        return $user;
    }

    public function test_it_generates_its_own_uuid_key(): void
    {
        $user = $this->staff();

        $this->assertTrue(
            Str::isUuid($user->id),
            'The key is not a UUID. 08 Section 3 types it uuid, and an auto-incrementing '
            .'integer would also leak how many accounts exist.'
        );

        // The accessors, not the properties: HasUuids leaves `$incrementing`
        // and `$keyType` at their defaults and overrides `getIncrementing()` and
        // `getKeyType()` instead, and the accessors are what Eloquent consults.
        $this->assertFalse($user->getIncrementing(), 'A UUID key must not be treated as incrementing.');
        $this->assertSame('string', $user->getKeyType());
    }

    public function test_role_and_status_come_back_as_enums(): void
    {
        $user = $this->staff()->fresh();

        $this->assertInstanceOf(
            Role::class,
            $user->role,
            'role came back as a loose string. Every caller would then compare against a literal, '
            .'and a typo would silently never match.'
        );

        $this->assertInstanceOf(UserStatus::class, $user->status);
        $this->assertSame(Role::Admin, $user->role);
        $this->assertSame(UserStatus::Active, $user->status);
    }

    public function test_a_plaintext_password_is_hashed_before_it_reaches_the_database(): void
    {
        $plaintext = 'correct horse battery staple';

        $user = $this->staff(['password' => $plaintext]);

        $stored = (string) DB::table('users')->where('id', $user->id)->value('password');

        $this->assertNotSame(
            $plaintext,
            $stored,
            'The password reached the database in plaintext. AGENTS.md Section 6 forbids storing '
            .'a password in a recoverable form.'
        );

        $this->assertTrue(
            Hash::check($plaintext, $stored),
            'The stored value is not a hash of the password that was set.'
        );
    }

    public function test_a_password_that_is_already_hashed_is_not_hashed_a_second_time(): void
    {
        // The hash has to be reassigned, not merely left alone: Eloquent writes
        // only the attributes that are dirty, so touching an unrelated field
        // would prove nothing — the column would not be in the statement at all.
        // Code that reads a user, sets `password` from what it already holds and
        // saves is ordinary, and without the guard it would re-hash the hash and
        // destroy the account's password with nobody touching it.
        $user = $this->staff();
        $first = (string) DB::table('users')->where('id', $user->id)->value('password');

        $user->password = $first;
        $user->full_name = 'Renamed';
        $user->save();

        $this->assertSame(
            $first,
            (string) DB::table('users')->where('id', $user->id)->value('password'),
            'Saving an unrelated field re-hashed the password.'
        );
    }

    public function test_a_customer_keeps_a_null_password(): void
    {
        $user = new User;
        $user->forceFill([
            'role' => Role::Customer,
            'phone' => '+998901234567',
            'password' => null,
            'status' => UserStatus::Active,
            'must_change_password' => false,
        ]);
        $user->save();

        $this->assertNull(
            DB::table('users')->where('id', $user->id)->value('password'),
            'A null password was turned into a hash of nothing, which the database CHECK forbids '
            .'and which would give a Customer a password nobody knows.'
        );
    }

    public function test_the_password_never_appears_in_the_serialized_model(): void
    {
        $user = $this->staff();

        $this->assertArrayNotHasKey('password', $user->toArray());

        // The hash itself, not the word: `must_change_password` is a legitimate
        // attribute whose name contains it.
        $this->assertStringNotContainsString(
            (string) $user->getAuthPassword(),
            $user->toJson(),
            'The password hash is serialized. Any endpoint returning a user would publish it, '
            .'which AGENTS.md Section 6 forbids.'
        );
    }

    public function test_the_fields_the_server_is_authoritative_over_cannot_be_mass_assigned(): void
    {
        // AGENTS.md Section 6: the backend is authoritative for the role and for
        // the active/blocked state. A controller that ever passes request input
        // straight into the model must not be able to hand out a role with it.
        $user = new User([
            'role' => Role::Admin,
            'status' => UserStatus::Active,
            'must_change_password' => false,
            'created_by_user_id' => (string) Str::uuid(),
            'phone' => '+998901234567',
        ]);

        foreach (['role', 'status', 'must_change_password', 'created_by_user_id'] as $field) {
            $this->assertNull(
                $user->getAttribute($field),
                sprintf('%s was set by mass assignment; it is the server\'s to decide.', $field)
            );
        }

        $this->assertSame('+998901234567', $user->phone, 'phone is ordinary input and stays fillable.');
    }

    public function test_the_gate_and_the_instants_are_typed(): void
    {
        $user = $this->staff(['must_change_password' => true, 'last_login_at' => now()])->fresh();

        // assertTrue is strict, so this also rules out the string "1" the driver
        // would hand back without the boolean cast.
        $this->assertTrue($user->must_change_password);
        $this->assertInstanceOf(Carbon::class, $user->last_login_at);
    }

    public function test_it_can_issue_a_sanctum_token(): void
    {
        // The `users` table and the delivered `personal_access_tokens` table have
        // to actually fit together: the token table keys `tokenable` by UUID, and
        // a mismatch would only show up the first time anyone logged in.
        $this->assertContains(HasApiTokens::class, class_uses_recursive(User::class));

        $user = $this->staff();
        $token = $user->createToken('test');

        $this->assertSame(
            $user->id,
            (string) DB::table('personal_access_tokens')->where('id', $token->accessToken->id)->value('tokenable_id')
        );
    }
}
