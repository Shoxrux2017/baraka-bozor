<?php

declare(strict_types=1);

namespace Tests\Feature\Support;

use App\Exceptions\ApiException;
use App\Models\Cart;
use App\Models\Enums\IdempotencyState;
use App\Models\IdempotencyKey;
use App\Models\User;
use App\Support\Idempotency\Attempt;
use App\Support\Idempotency\IdempotencyStore;
use App\Support\Idempotency\RequestFingerprint;
use DateTimeInterface;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Tests\TestCase;

/**
 * The idempotency store of `docs/07` Section 17 and `DL-37` (5), with a cart
 * standing in for the resource an operation produces.
 *
 * Two requests with one key at the same instant are held apart by PostgreSQL
 * — the insert conflicts on the unique key and the loser reads the row under
 * `FOR UPDATE` — and cannot be raced inside one test transaction; the tests
 * put the row in each state a concurrent second request can meet instead.
 */
final class IdempotencyStoreTest extends TestCase
{
    use RefreshDatabase;

    private IdempotencyStore $store;

    private User $customer;

    private int $performed = 0;

    protected function setUp(): void
    {
        parent::setUp();

        $this->store = new IdempotencyStore;
        $this->customer = User::factory()->customer()->create();
    }

    private function attempt(string $key, string $hash, string $operation = 'carts.create', ?User $actor = null): Cart
    {
        $actor ??= $this->customer;

        return $this->store->run(
            $actor->id,
            $operation,
            $key,
            $hash,
            function () use ($actor): Cart {
                $this->performed++;

                return Cart::factory()->converted()->create(['customer_id' => $actor->id]);
            },
            static fn (string $id): Cart => Cart::query()->findOrFail($id),
        );
    }

    private function hash(string $body = 'a'): string
    {
        return RequestFingerprint::of('carts.create', [], ['body' => $body]);
    }

    public function test_a_new_key_runs_the_operation_once_and_completes_with_its_resource(): void
    {
        $key = (string) Str::uuid();

        $cart = $this->attempt($key, $this->hash());

        $row = IdempotencyKey::query()->sole();
        $this->assertSame(1, $this->performed);
        $this->assertSame(IdempotencyState::Completed, $row->state);
        $this->assertSame('carts', $row->resource_type);
        $this->assertSame($cart->id, $row->resource_id);
        $this->assertNotNull($row->completed_at);
    }

    public function test_the_same_key_and_request_replay_the_same_resource_without_running_again(): void
    {
        $key = (string) Str::uuid();
        $first = $this->attempt($key, $this->hash());

        $again = $this->attempt($key, $this->hash());

        $this->assertSame($first->id, $again->id);
        $this->assertSame(1, $this->performed);
        $this->assertSame(1, Cart::query()->count());
    }

    public function test_the_same_key_with_another_request_is_a_key_reused(): void
    {
        $key = (string) Str::uuid();
        $this->attempt($key, $this->hash('a'));

        $this->assertRefusedWith('idempotency_key_reused', fn () => $this->attempt($key, $this->hash('b')));
        $this->assertSame(1, $this->performed);
    }

    public function test_a_key_still_processing_inside_its_lease_is_in_progress(): void
    {
        $key = (string) Str::uuid();
        $this->processingRow($key, leaseExpiresAt: now()->addSeconds(IdempotencyStore::LEASE_SECONDS));

        $this->travel(59)->seconds();

        $this->assertRefusedWith('idempotency_in_progress', fn () => $this->attempt($key, $this->hash()));
        $this->assertSame(0, $this->performed);
    }

    public function test_a_key_left_processing_past_its_lease_is_taken_over_and_run_again(): void
    {
        $key = (string) Str::uuid();
        $row = $this->processingRow($key, leaseExpiresAt: now()->addSeconds(IdempotencyStore::LEASE_SECONDS));

        $this->travel(61)->seconds();
        $cart = $this->attempt($key, $this->hash());

        $taken = $row->fresh();
        $this->assertNotNull($taken);
        $this->assertSame(IdempotencyState::Completed, $taken->state);
        $this->assertSame($cart->id, $taken->resource_id);
        $this->assertNotSame($row->attempt_token, $taken->attempt_token);
        $this->assertSame(1, $this->performed);
    }

    public function test_a_refusal_deletes_the_key_so_a_retry_is_judged_again(): void
    {
        $key = (string) Str::uuid();

        $this->assertRefusedWith('business_conflict', fn () => $this->store->run(
            $this->customer->id,
            'carts.create',
            $key,
            $this->hash(),
            static fn (): Cart => throw ApiException::conflict('business_conflict'),
            static fn (string $id): Cart => Cart::query()->findOrFail($id),
        ));
        $this->assertSame(0, IdempotencyKey::query()->count());

        $this->attempt($key, $this->hash());
        $this->assertSame(1, $this->performed);
        $this->assertSame(IdempotencyState::Completed, IdempotencyKey::query()->sole()->state);
    }

    public function test_an_attempt_that_outran_its_lease_neither_completes_over_nor_erases_the_takeover(): void
    {
        $key = (string) Str::uuid();
        $late = $this->store->begin($this->customer->id, 'carts.create', $key, $this->hash());
        $this->assertInstanceOf(Attempt::class, $late);

        // The late attempt's lease runs out and another attempt takes the key.
        $this->travel(IdempotencyStore::LEASE_SECONDS + 1)->seconds();
        $takeover = $this->store->begin($this->customer->id, 'carts.create', $key, $this->hash());
        $this->assertInstanceOf(Attempt::class, $takeover);
        $this->assertSame($late->id, $takeover->id);
        $this->assertNotSame($late->attemptToken, $takeover->attemptToken);

        $cart = Cart::factory()->create(['customer_id' => $this->customer->id]);
        $this->assertRefusedWith('idempotency_in_progress', fn () => $this->store->complete($late, $cart));
        $this->store->abandon($late);

        $row = IdempotencyKey::query()->sole();
        $this->assertSame(IdempotencyState::Processing, $row->state, 'The record of the takeover survives the late attempt.');
        $this->assertSame($takeover->attemptToken, $row->attempt_token);

        $this->store->complete($takeover, $cart);
        $this->assertSame(IdempotencyState::Completed, $row->fresh()?->state);
    }

    public function test_run_rolls_the_operation_back_when_the_key_cannot_be_completed(): void
    {
        $key = (string) Str::uuid();

        $this->assertRefusedWith('idempotency_in_progress', fn () => $this->store->run(
            $this->customer->id,
            'carts.create',
            $key,
            $this->hash(),
            function (): Cart {
                $cart = Cart::factory()->create(['customer_id' => $this->customer->id]);
                // As if another attempt had taken the key while this one worked.
                IdempotencyKey::query()->update(['attempt_token' => (string) Str::uuid()]);

                return $cart;
            },
            static fn (string $id): Cart => Cart::query()->findOrFail($id),
        ));

        $this->assertSame(0, Cart::query()->count(), 'The work of an attempt that lost its key is rolled back.');
    }

    public function test_a_key_belongs_to_its_actor_and_operation(): void
    {
        $key = (string) Str::uuid();
        $other = User::factory()->customer()->create();

        $mine = $this->attempt($key, $this->hash());
        $theirs = $this->attempt($key, $this->hash(), actor: $other);
        $anotherOperation = $this->attempt($key, RequestFingerprint::of('carts.other', [], []), operation: 'carts.other');

        $this->assertSame(3, $this->performed);
        $this->assertNotSame($mine->id, $theirs->id);
        $this->assertNotSame($mine->id, $anotherOperation->id);
        $this->assertSame(3, IdempotencyKey::query()->count());
    }

    private function processingRow(string $key, DateTimeInterface $leaseExpiresAt): IdempotencyKey
    {
        $row = (new IdempotencyKey)->forceFill([
            'actor_user_id' => $this->customer->id,
            'operation' => 'carts.create',
            'idempotency_key' => $key,
            'request_hash' => $this->hash(),
            'state' => IdempotencyState::Processing,
            'attempt_token' => (string) Str::uuid(),
            'lease_expires_at' => $leaseExpiresAt,
        ]);
        $row->save();

        return $row;
    }

    private function assertRefusedWith(string $code, callable $attempt): void
    {
        try {
            $attempt();
        } catch (ApiException $refusal) {
            $this->assertSame($code, $refusal->apiCode());

            return;
        }

        $this->fail("Expected a refusal with {$code}.");
    }
}
