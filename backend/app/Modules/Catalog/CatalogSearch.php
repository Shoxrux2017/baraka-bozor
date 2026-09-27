<?php

declare(strict_types=1);

namespace App\Modules\Catalog;

use App\Support\Search\TextSearch;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/**
 * Catalog search and ordering shared by the Admin and Customer lists.
 *
 * Search matches either name as a substring (`BR-CAT-005`, `DL-17` (10)),
 * folded as `TextSearch` folds it, so the catalog, written with the plain `'`
 * (`DL-16`), is found however a phone types the Uzbek apostrophe.
 *
 * Ordering is `sort_order`, then `name_uz`, then the id, so a page boundary
 * never shuffles two rows with equal sort keys. Columns are qualified with
 * the model's table, so a caller may join without making them ambiguous.
 */
final class CatalogSearch
{
    /** The longest search term accepted. */
    public const MAX_TERM_LENGTH = TextSearch::MAX_TERM_LENGTH;

    /**
     * @template TModel of Model
     *
     * @param  Builder<TModel>  $query
     * @return Builder<TModel>
     */
    public static function matching(Builder $query, ?string $term): Builder
    {
        if ($term === null || trim($term) === '') {
            return $query;
        }

        $uz = $query->qualifyColumn('name_uz');
        $ru = $query->qualifyColumn('name_ru');

        return $query->where(static function (Builder $names) use ($term, $uz, $ru): void {
            TextSearch::contains($names, $uz, $term);
            TextSearch::contains($names, $ru, $term, 'or');
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
        return $query
            ->orderBy($query->qualifyColumn('sort_order'))
            ->orderBy($query->qualifyColumn('name_uz'))
            ->orderBy($query->qualifyColumn('id'));
    }
}
