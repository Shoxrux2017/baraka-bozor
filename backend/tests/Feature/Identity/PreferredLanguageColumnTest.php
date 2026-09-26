<?php

declare(strict_types=1);

namespace Tests\Feature\Identity;

use App\Models\Enums\Role;
use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\Support\Database\AssertsDatabaseRejections;
use Tests\Support\Database\ReadsPostgresCatalog;
use Tests\TestCase;

/**
 * `users.preferred_language`, docs/08 Section 3.
 */
final class PreferredLanguageColumnTest extends TestCase
{
    use AssertsDatabaseRejections;
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    public function test_the_column_is_a_two_character_non_null_string_defaulting_to_uzbek(): void
    {
        $column = $this->columnsOf('users')['preferred_language'] ?? null;

        $this->assertNotNull($column);
        $this->assertSame('character varying', $column->data_type);
        $this->assertSame(2, $column->character_maximum_length);
        $this->assertSame('NO', $column->is_nullable);

        $user = User::factory()->role(Role::Operator)->create();
        $this->assertSame('uz', $user->fresh()?->preferred_language);
    }

    public function test_only_uzbek_and_russian_are_accepted(): void
    {
        $this->assertRejectedBy('users', 'users_preferred_language_check', [
            'id' => (string) Str::uuid(),
            'role' => 'operator',
            'phone' => '+998901234567',
            'password' => 'hash',
            'status' => 'active',
            'must_change_password' => false,
            'preferred_language' => 'en',
            'created_at' => now(),
            'updated_at' => now(),
        ], 'The client languages are Uzbek and Russian only (DL-2, topic 8).');
    }
}
