<?php

declare(strict_types=1);

namespace App\Support\Scope;

use App\Exceptions\ApiException;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

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
     * @template TModel of Model
     *
     * @param  Builder<TModel>  $scopedQuery
     * @return TModel
     */
    public static function lockOrNotFound(Builder $scopedQuery): Model
    {
        return self::firstOrNotFound($scopedQuery->lockForUpdate());
    }
}
