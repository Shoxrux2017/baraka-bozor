<?php

declare(strict_types=1);

namespace App\Modules\Catalog;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/**
 * Catalog search and ordering shared by the Admin and Customer lists.
 *
 * Search matches either name, in either case, as a substring (`BR-CAT-005`,
 * `DL-17` (10)). PostgreSQL lowercases both the column and the pattern, so
 * Cyrillic and Latin fold the way the database folds them. The term's own
 * `%`, `_` and `\` are escaped, so a Customer typing "50%" looks for "50%"
 * rather than for anything starting with "50".
 *
 * Ordering is `sort_order`, then `name_uz`, then the id, so a page boundary
 * never shuffles two rows with equal sort keys.
 */
final class CatalogSearch
{
    /** The longest search term accepted. */
    public const MAX_TERM_LENGTH = 100;

    /**
     * @template TModel of Model
     *
     * @param  Builder<TModel>  $query
     * @return Builder<TModel>
     */
    public static function matching(Builder $query, ?string $term): Builder
    {
        if ($term === null || $term === '') {
            return $query;
        }

        $pattern = '%'.addcslashes($term, '\\%_').'%';

        return $query->where(static function (Builder $names) use ($pattern): void {
            $names->whereRaw('lower(name_uz) like lower(?)', [$pattern])
                ->orWhereRaw('lower(name_ru) like lower(?)', [$pattern]);
        });
    }

    /**
     * @template TModel of Model
     *
     * @param  Builder<TModel>  $query
     * @return Builder<TModel>
     */
    public static function ordered(Builder $query): Builder
    {
        return $query->orderBy('sort_order')->orderBy('name_uz')->orderBy('id');
    }
}
