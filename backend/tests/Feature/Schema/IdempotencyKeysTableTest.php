<?php

declare(strict_types=1);

namespace Tests\Feature\Schema;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\Support\Database\AssertsDatabaseRejections;
use Tests\TestCase;

/**
 * `idempotency_keys`, as `docs/08-database.md` Section 27 names it, with the
 * attempt token of `DL-37` (5).
 */
final class IdempotencyKeysTableTest extends TestCase
{
    use AssertsDatabaseRejections;
    use RefreshDatabase;

    private const TABLE = 'idempotency_keys';

    /**
     * @param  array<string, mixed>  $overrides
     * @return array<string, mixed>
     */
    private function row(array $overrides = []): array
    {
        return array_merge([
            'id' => (string) Str::uuid(),
            'actor_user_id' => User::factory()->customer()->create()->id,
            'operation' => 'create_order',
            'idempotency_key' => (string) Str::uuid(),
            'request_hash' => hash('sha256', '{}'),
            'state' => 'processing',
            'attempt_token' => (string) Str::uuid(),
            'lease_expires_at' => now()->addMinute(),
            'created_at' => now(),
        ], $overrides);
    }

    public function test_a_key_is_unique_per_actor_and_operation(): void
    {
        $first = $this->row();
        DB::table(self::TABLE)->insert($first);
        DB::table(self::TABLE)->insert($this->row(['idempotency_key' => $first['idempotency_key'], 'operation' => 'cancel_order', 'actor_user_id' => $first['actor_user_id']]));
        DB::table(self::TABLE)->insert($this->row(['idempotency_key' => $first['idempotency_key']]));

        $this->assertRejectedBy(
            self::TABLE,
            'idempotency_keys_actor_user_id_operation_idempotency_key_unique',
            $this->row(['idempotency_key' => $first['idempotency_key'], 'actor_user_id' => $first['actor_user_id']]),
            'docs/07 section 17: one row per (actor, operation, key).'
        );
    }

    public function test_a_completed_key_names_its_result_and_when(): void
    {
        $this->assertRejectedBy(
            self::TABLE,
            'idempotency_keys_completed_check',
            $this->row(['state' => 'completed', 'completed_at' => now()]),
            'A replay needs the resource it replays.'
        );
        $this->assertRejectedBy(
            self::TABLE,
            'idempotency_keys_completed_check',
            $this->row(['completed_at' => now()]),
            'Only a completed key has completed_at.'
        );
        DB::table(self::TABLE)->insert($this->row([
            'state' => 'completed',
            'completed_at' => now(),
            'resource_type' => 'order',
            'resource_id' => (string) Str::uuid(),
        ]));
        $this->assertSame(1, DB::table(self::TABLE)->count());
    }

    public function test_the_hash_is_a_sha256_hex_digest_and_the_state_is_known(): void
    {
        $this->assertRejectedBy(self::TABLE, 'idempotency_keys_request_hash_check', $this->row(['request_hash' => str_repeat('Z', 64)]), 'Lower-case hex SHA-256.');
        $this->assertRejectedBy(self::TABLE, 'idempotency_keys_state_check', $this->row(['state' => 'failed']), 'A refusal deletes the row (DL-37 (5)); there is no failed state.');
    }
}
