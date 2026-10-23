<?php

declare(strict_types=1);

namespace Tests\Feature\Console;

use App\Models\User;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * `idempotency-keys:prune` — `docs/08` section 27, `DL-104` (8): a key thirty
 * days finished, or thirty days past a dead attempt's lease, is deleted.
 */
final class PruneIdempotencyKeysCommandTest extends TestCase
{
    use RefreshDatabase;

    public function test_it_prunes_only_what_is_thirty_days_dead_and_a_second_run_changes_nothing(): void
    {
        $this->travelTo(now()->startOfSecond());
        $actor = User::factory()->customer()->create();

        $this->key($actor, 'completed', completedAt: now()->subDays(31));
        $keptCompleted = $this->key($actor, 'completed', completedAt: now()->subDays(29));
        $this->key($actor, 'processing', leaseExpiresAt: now()->subDays(31));
        $keptDead = $this->key($actor, 'processing', leaseExpiresAt: now()->subDays(1));
        $keptLive = $this->key($actor, 'processing', leaseExpiresAt: now()->addMinute());

        $this->artisan('idempotency-keys:prune')->expectsOutput('Pruned 2 idempotency key(s).')->assertSuccessful();
        $this->assertEqualsCanonicalizing([$keptCompleted, $keptDead, $keptLive], DB::table('idempotency_keys')->pluck('id')->all());

        $this->artisan('idempotency-keys:prune')->expectsOutput('Pruned 0 idempotency key(s).')->assertSuccessful();
        $this->assertEqualsCanonicalizing([$keptCompleted, $keptDead, $keptLive], DB::table('idempotency_keys')->pluck('id')->all());
    }

    private function key(User $actor, string $state, $completedAt = null, $leaseExpiresAt = null): string
    {
        $id = (string) Str::uuid();
        DB::table('idempotency_keys')->insert([
            'id' => $id,
            'actor_user_id' => $actor->id,
            'operation' => 'orders.reorder',
            'idempotency_key' => (string) Str::uuid(),
            'request_hash' => str_repeat('a', 64),
            'state' => $state,
            'attempt_token' => (string) Str::uuid(),
            'lease_expires_at' => $leaseExpiresAt ?? $completedAt,
            'response' => $state === 'completed' ? json_encode(['x' => 1]) : null,
            'created_at' => now()->subDays(40),
            'completed_at' => $completedAt,
        ]);

        return $id;
    }
}
