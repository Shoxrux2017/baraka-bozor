<?php

declare(strict_types=1);

namespace App\Support\Scope;

use App\Exceptions\ApiException;
use Illuminate\Database\ConnectionInterface;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use LogicException;

/**
 * Layer 4 of `docs/07-architecture.md` Section 9: ownership and assignment
 * scope, with the scope-safe answer `backend/AGENTS.md` Section 4 requires.
 *
 * An action builds the query already narrowed to what the actor may see — a
 * Customer's own orders, a Shopper's current assignments — and asks for one
 * record. A record outside the scope and a record that does not exist answer
 * the same `404 resource_not_found`, so a valid UUID reveals nothing about
 * what it would have pointed at. Finding the record first and deciding
 * afterwards is the pattern this exists to replace.
 *
 * Two rules for the scoped query. Narrow with `where` and `whereExists`, not
 * joins: PostgreSQL's `FOR UPDATE` locks the rows of every joined table, which
 * breaks the lock order of `docs/07` Section 16. And pass an Eloquent
 * `Builder`; a relation such as `$customer->orders()` is converted with
 * `->getQuery()`.
 *
 * Route parameters that carry a UUID are constrained by `UuidRouteParameters`,
 * so a malformed id never reaches a query and answers the same 404.
 */
final class ScopedLookup
{
    /**
     * @template TModel of Model
     *
     * @param  Builder<TModel>  $scopedQuery
     * @return TModel
     */
    public static function firstOrNotFound(Builder $scopedQuery): Model
    {
        $record = $scopedQuery->first();

        if ($record === null) {
            throw ApiException::notFound();
        }

        return $record;
    }

    /**
     * The same, holding a row lock for a mutation under `docs/07` Section 16.
     *
     * Only inside a transaction: PostgreSQL releases a `FOR UPDATE` lock at the
     * end of the statement in autocommit mode, so outside one the lock would be
     * gone before the mutation it protects — silently. Refused instead.
     *
     * @template TModel of Model
     *
     * @param  Builder<TModel>  $scopedQuery
     * @return TModel
     */
    public static function lockOrNotFound(Builder $scopedQuery): Model
    {
        self::assertInsideTransaction($scopedQuery->getConnection());

        return self::firstOrNotFound($scopedQuery->lockForUpdate());
    }

    public static function assertInsideTransaction(ConnectionInterface $connection): void
    {
        if ($connection->transactionLevel() === 0) {
            throw new LogicException(
                'ScopedLookup::lockOrNotFound must run inside a database transaction; '
                .'a row lock taken outside one is released before the mutation it protects.'
            );
        }
    }
}
