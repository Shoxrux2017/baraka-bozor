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
     * The names of every index PostgreSQL actually holds on $table.
     *
     * @return list<string>
     */
    private function indexesOn(string $table): array
    {
        /** @var list<object{indexname: string}> $rows */
        $rows = DB::select(
            'select indexname from pg_indexes where schemaname = current_schema() and tablename = ?',
            [$table]
        );

        return array_map(static fn (object $row): string => (string) $row->indexname, $rows);
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
