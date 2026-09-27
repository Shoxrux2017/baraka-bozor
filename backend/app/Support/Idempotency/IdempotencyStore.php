<?php

declare(strict_types=1);

namespace App\Support\Idempotency;

use App\Exceptions\ApiException;
use App\Models\Enums\IdempotencyState;
use App\Models\IdempotencyKey;
use Closure;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use LogicException;
use Throwable;

/**
 * The persisted `Idempotency-Key` contract of `docs/07` Section 17 and
 * `docs/09` Section 48, with the transaction boundary of `DL-37` (5).
 *
 * `run()` binds a key to its actor, operation and request hash, then:
 *
 * - a new key: the key is committed as `processing` under a 60-second lease
 *   in its own short transaction; the operation runs in a second transaction,
 *   which also marks the key `completed` with the resource it produced, so a
 *   completed key never exists without its effect;
 * - the same key and hash, completed: the resource is loaded and returned as
 *   it is now — the same logical result, not a stored response;
 * - the same key and hash, still processing inside its lease:
 *   `409 idempotency_in_progress`;
 * - the same key and hash, processing past its lease: the attempt died, so
 *   this one takes the row over and runs the operation again;
 * - the same key with another hash: `409 idempotency_key_reused`.
 *
 * A refusal or any other failure of the operation deletes the key, so a retry
 * is judged again rather than told `in_progress` for a minute. Every attempt
 * owns the row through a fresh `attempt_token`; completing and deleting act
 * only on a row still `processing` with that token, so an attempt that outran
 * its lease can neither complete over nor erase the record of the attempt that
 * took over — its own work is rolled back and it answers `in_progress`.
 *
 * Concurrency rests on PostgreSQL: the key is inserted with `on conflict do
 * nothing` against the unique `(actor, operation, key)`, and a key that exists
 * is read under `FOR UPDATE`, so two requests with one key cannot both begin.
 *
 * Rules for a caller (`DL-39`):
 *
 * - Call `run()` at transaction level 0. Inside an outer transaction `begin()`
 *   is only a savepoint: no lease is committed, a second request waits on the
 *   unique key until the outer transaction ends, and a takeover can deadlock.
 * - Only effects that roll back with the transaction belong in `$perform`. A
 *   push, a queued job or a provider call is dispatched after commit
 *   (`DB::afterCommit`) from inside `$perform`: a replay does not run
 *   `$perform`, so such an effect is neither lost to a rollback nor repeated.
 * - `$replay` loads the resource through the actor's current scope
 *   (`ScopedLookup::firstOrNotFound`). A replay skips every check inside
 *   `$perform`, so a record the actor may no longer see — a Shopper since
 *   reassigned — must be the scope-safe `404`, never the record.
 *
 * `begin()`, `complete()` and `abandon()` are the steps `run()` composes,
 * public so each can be proven on its own, against a second connection.
 */
final class IdempotencyStore
{
    public const LEASE_SECONDS = 60;

    /**
     * @template TModel of Model
     *
     * @param  string  $operation  a stable name, such as `orders.create`
     * @param  string  $key  the `Idempotency-Key`, already checked to be a UUID
     * @param  string  $requestHash  `RequestFingerprint::of(...)`
     * @param  Closure(): TModel  $perform  the operation; runs inside the transaction that completes the key
     * @param  Closure(string): TModel  $replay  loads the resource a completed key names, through the actor's current scope
     * @return TModel
     */
    public function run(string $actorId, string $operation, string $key, string $requestHash, Closure $perform, Closure $replay): Model
    {
        $begun = $this->begin($actorId, $operation, $key, $requestHash);

        if ($begun instanceof Replay) {
            return $replay($begun->resourceId);
        }

        try {
            return DB::transaction(function () use ($begun, $perform): Model {
                $resource = $perform();
                $this->complete($begun, $resource);

                return $resource;
            });
        } catch (Throwable $failure) {
            try {
                $this->abandon($begun);
            } catch (Throwable $abandonFailure) {
                // The key then waits out its lease; the caller still learns
                // why the operation failed, not why the clean-up did.
                report($abandonFailure);
            }

            throw $failure;
        }
    }

    /**
     * Commits the key as this request's, or finds it done, in progress or
     * reused. Runs in its own short transaction.
     */
    public function begin(string $actorId, string $operation, string $key, string $requestHash): Attempt|Replay
    {
        return DB::transaction(function () use ($actorId, $operation, $key, $requestHash): Attempt|Replay {
            $id = (string) Str::uuid();
            $attemptToken = (string) Str::uuid();

            $inserted = DB::table('idempotency_keys')->insertOrIgnore([
                'id' => $id,
                'actor_user_id' => $actorId,
                'operation' => $operation,
                'idempotency_key' => $key,
                'request_hash' => $requestHash,
                'state' => IdempotencyState::Processing->value,
                'attempt_token' => $attemptToken,
                'lease_expires_at' => now()->addSeconds(self::LEASE_SECONDS),
                'created_at' => now(),
            ]);

            if ($inserted === 1) {
                return new Attempt($id, $attemptToken);
            }

            $existing = IdempotencyKey::query()
                ->where('actor_user_id', $actorId)
                ->where('operation', $operation)
                ->where('idempotency_key', $key)
                ->lockForUpdate()
                ->first();

            if ($existing === null) {
                // The conflicting row was deleted between the insert and the
                // read: an attempt was refused and abandoned its key. Only a
                // real race reaches this; the client's retry begins afresh.
                throw ApiException::conflict('idempotency_in_progress');
            }

            if (! hash_equals($existing->request_hash, $requestHash)) {
                throw ApiException::conflict('idempotency_key_reused');
            }

            if ($existing->state === IdempotencyState::Completed) {
                return new Replay($existing->resource_id ?? throw new LogicException('A completed key names its resource.'));
            }

            if ($existing->lease_expires_at->isFuture()) {
                throw ApiException::conflict('idempotency_in_progress');
            }

            $existing->forceFill([
                'attempt_token' => $attemptToken,
                'lease_expires_at' => now()->addSeconds(self::LEASE_SECONDS),
            ])->save();

            return new Attempt($existing->id, $attemptToken);
        });
    }

    /**
     * Marks the key completed with the resource, inside the operation's
     * transaction — only while this attempt still owns it. An attempt that lost
     * the key to a takeover is refused, so its transaction rolls back and the
     * effect is left to the attempt that took over.
     */
    public function complete(Attempt $attempt, Model $resource): void
    {
        $completed = IdempotencyKey::query()
            ->whereKey($attempt->id)
            ->where('state', IdempotencyState::Processing->value)
            ->where('attempt_token', $attempt->attemptToken)
            ->update([
                'state' => IdempotencyState::Completed->value,
                'resource_type' => $resource->getTable(),
                'resource_id' => (string) $resource->getKey(),
                'completed_at' => now(),
            ]);

        if ($completed !== 1) {
            throw ApiException::conflict('idempotency_in_progress');
        }
    }

    /**
     * Deletes the key after a failed attempt, so a retry is judged again —
     * only while this attempt still owns it.
     */
    public function abandon(Attempt $attempt): void
    {
        IdempotencyKey::query()
            ->whereKey($attempt->id)
            ->where('state', IdempotencyState::Processing->value)
            ->where('attempt_token', $attempt->attemptToken)
            ->delete();
    }
}
