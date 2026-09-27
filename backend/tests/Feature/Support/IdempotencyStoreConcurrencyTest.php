<?php

declare(strict_types=1);

namespace Tests\Feature\Support;

use App\Exceptions\ApiException;
use App\Models\Cart;
use App\Models\User;
use App\Support\Idempotency\Attempt;
use App\Support\Idempotency\IdempotencyStore;
use App\Support\Idempotency\RequestFingerprint;
use Illuminate\Database\Connection;
use Illuminate\Database\QueryException;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * The transaction boundary the idempotency store rests on (`DL-37` (5),
 * `DL-39`), proven with real commits and a second connection — the way two
 * requests meet in production. No test transaction wraps these tests, so each
 * cleans up what it committed.
 *
 * A waiting statement is cut short by `lock_timeout`: a statement that times
 * out was waiting on the other connection's uncommitted row, which is the
 * behaviour under test.
 */
final class IdempotencyStoreConcurrencyTest extends TestCase
{
    private const SECOND = 'pgsql_second';

    private const LOCK_NOT_AVAILABLE = '55P03';

    private IdempotencyStore $store;

    private User $customer;

    protected function setUp(): void
    {
        parent::setUp();

        // Another class's RefreshDatabase migrates the test database fresh;
        // run first, this class migrates it itself.
        if (! Schema::hasTable('idempotency_keys')) {
            $this->artisan('migrate');
        }

        config(['database.connections.'.self::SECOND => config('database.connections.pgsql')]);

        $this->store = new IdempotencyStore;
        $this->customer = User::factory()->customer()->create();
    }

    protected function tearDown(): void
    {
        $second = $this->second();
        while ($second->transactionLevel() > 0) {
            $second->rollBack();
        }
        DB::purge(self::SECOND);

        DB::statement('reset lock_timeout');
        DB::table('idempotency_keys')->where('actor_user_id', $this->customer->id)->delete();
        DB::table('carts')->where('customer_id', $this->customer->id)->delete();
        DB::table('users')->where('id', $this->customer->id)->delete();

        parent::tearDown();
    }

    public function test_begin_commits_the_processing_key_on_its_own(): void
    {
        $this->assertSame(0, DB::transactionLevel(), 'No test transaction wraps this class.');

        $attempt = $this->store->begin($this->customer->id, 'carts.create', (string) Str::uuid(), $this->hash());
        $this->assertInstanceOf(Attempt::class, $attempt);

        $seen = $this->second()->table('idempotency_keys')->where('id', $attempt->id)->first();
        $this->assertNotNull($seen, 'Another request sees the key while the operation has not even started.');
        $this->assertSame('processing', $seen->state);
    }

    public function test_a_refused_run_leaves_no_key_and_no_effect_for_anyone(): void
    {
        try {
            $this->store->run(
                $this->customer->id,
                'carts.create',
                (string) Str::uuid(),
                $this->hash(),
                function (): Cart {
                    Cart::factory()->create(['customer_id' => $this->customer->id]);

                    throw ApiException::conflict('business_conflict');
                },
                static fn (string $id): Cart => Cart::query()->findOrFail($id),
            );
            $this->fail('The operation was refused.');
        } catch (ApiException $refusal) {
            $this->assertSame('business_conflict', $refusal->apiCode());
        }

        $this->assertSame(0, $this->second()->table('idempotency_keys')->where('actor_user_id', $this->customer->id)->count());
        $this->assertSame(0, $this->second()->table('carts')->where('customer_id', $this->customer->id)->count());
    }

    public function test_a_second_request_waits_for_an_uncommitted_first_and_then_finds_it_in_progress(): void
    {
        $key = (string) Str::uuid();

        // The first request has inserted the key and not yet committed.
        $second = $this->second();
        $second->beginTransaction();
        $second->table('idempotency_keys')->insert([
            'id' => (string) Str::uuid(),
            'actor_user_id' => $this->customer->id,
            'operation' => 'carts.create',
            'idempotency_key' => $key,
            'request_hash' => $this->hash(),
            'state' => 'processing',
            'attempt_token' => (string) Str::uuid(),
            'lease_expires_at' => now()->addSeconds(IdempotencyStore::LEASE_SECONDS),
            'created_at' => now(),
        ]);

        DB::statement("set lock_timeout = '300ms'");
        $this->assertWaits(fn () => $this->store->begin($this->customer->id, 'carts.create', $key, $this->hash()));

        $second->commit();

        try {
            $this->store->begin($this->customer->id, 'carts.create', $key, $this->hash());
            $this->fail('The first request holds the key.');
        } catch (ApiException $refusal) {
            $this->assertSame('idempotency_in_progress', $refusal->apiCode());
        }
    }

    public function test_a_late_completion_waits_for_an_uncommitted_takeover_and_then_loses(): void
    {
        $key = (string) Str::uuid();
        $late = $this->store->begin($this->customer->id, 'carts.create', $key, $this->hash());
        $this->assertInstanceOf(Attempt::class, $late);
        $cart = Cart::factory()->create(['customer_id' => $this->customer->id]);

        // Past the late attempt's lease, a takeover locks the key and renews
        // the token, and has not yet committed.
        $second = $this->second();
        $second->beginTransaction();
        $second->table('idempotency_keys')->where('id', $late->id)->lockForUpdate()->first();
        $takeoverToken = (string) Str::uuid();
        $second->table('idempotency_keys')->where('id', $late->id)->update(['attempt_token' => $takeoverToken]);

        DB::statement("set lock_timeout = '300ms'");
        $this->assertWaits(fn () => DB::transaction(fn () => $this->store->complete($late, $cart)));

        $second->commit();

        try {
            DB::transaction(fn () => $this->store->complete($late, $cart));
            $this->fail('The late attempt lost the key.');
        } catch (ApiException $refusal) {
            $this->assertSame('idempotency_in_progress', $refusal->apiCode());
        }
        $this->store->abandon($late);

        $row = $this->second()->table('idempotency_keys')->where('id', $late->id)->first();
        $this->assertNotNull($row, 'The late attempt did not erase the takeover\'s key.');
        $this->assertSame('processing', $row->state);
        $this->assertSame($takeoverToken, $row->attempt_token);
    }

    private function second(): Connection
    {
        return DB::connection(self::SECOND);
    }

    private function hash(): string
    {
        return RequestFingerprint::of('carts.create', [], []);
    }

    private function assertWaits(callable $statement): void
    {
        try {
            $statement();
            $this->fail('The statement did not wait for the other connection.');
        } catch (QueryException $timeout) {
            $this->assertSame(self::LOCK_NOT_AVAILABLE, $timeout->getCode(), $timeout->getMessage());
        }
    }
}
