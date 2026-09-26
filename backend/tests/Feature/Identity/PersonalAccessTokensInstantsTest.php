<?php

declare(strict_types=1);

namespace Tests\Feature\Identity;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\Database\ReadsPostgresCatalog;
use Tests\TestCase;

/**
 * The Sanctum token table's instants are `timestamptz`, docs/08 Section 1,
 * because `last_used_at` is what the sliding token lifetime is measured from.
 */
final class PersonalAccessTokensInstantsTest extends TestCase
{
    use ReadsPostgresCatalog;
    use RefreshDatabase;

    public function test_every_instant_column_carries_a_time_zone(): void
    {
        $columns = $this->columnsOf('personal_access_tokens');

        foreach (['last_used_at', 'expires_at', 'created_at', 'updated_at'] as $name) {
            $this->assertSame(
                'timestamp with time zone',
                $columns[$name]->data_type ?? null,
                "{$name} must be timestamptz"
            );
        }
    }
}
