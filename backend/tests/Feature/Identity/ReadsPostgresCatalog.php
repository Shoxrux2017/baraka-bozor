<?php

declare(strict_types=1);

namespace Tests\Feature\Identity;

use Illuminate\Support\Facades\DB;

/**
 * Reads what PostgreSQL actually built, from its own catalog.
 *
 * A migration says what was requested; `information_schema` and `pg_indexes` say
 * what exists. The two diverge in exactly the cases a schema task most needs to
 * catch — `timestamps()` quietly producing `timestamp without time zone`, or a
 * nullable `created_at` — so every schema assertion in this directory asks the
 * server rather than re-reading the migration source.
 */
trait ReadsPostgresCatalog
{
    /**
     * Every index PostgreSQL actually holds on $table, name => definition.
     *
     * The definition and not just the name, because an index keeping its name
     * while losing its `WHERE` predicate or its `UNIQUE` is exactly the change
     * that would go unnoticed.
     *
     * @return array<string, string>
     */
    private function indexesOn(string $table): array
    {
        /** @var list<object{indexname: string, indexdef: string}> $rows */
        $rows = DB::select(
            'select indexname, indexdef from pg_indexes where schemaname = current_schema() and tablename = ?',
            [$table]
        );

        $byName = [];

        foreach ($rows as $row) {
            $byName[(string) $row->indexname] = (string) $row->indexdef;
        }

        return $byName;
    }

    /**
     * What PostgreSQL actually built for $table, keyed by column name.
     *
     * Asked of the catalog rather than read off the migration: a migration says
     * what was requested, the catalog says what exists, and the two diverge in
     * exactly the cases worth testing.
     *
     * @return array<string, object{data_type: string, is_nullable: string, character_maximum_length: int|null}>
     */
    private function columnsOf(string $table): array
    {
        $rows = DB::select(
            'select column_name, data_type, is_nullable, character_maximum_length
               from information_schema.columns
              where table_schema = current_schema() and table_name = ?',
            [$table]
        );

        $byName = [];

        foreach ($rows as $row) {
            /** @var object{column_name: string, data_type: string, is_nullable: string, character_maximum_length: int|null} $row */
            $byName[$row->column_name] = $row;
        }

        return $byName;
    }
}
