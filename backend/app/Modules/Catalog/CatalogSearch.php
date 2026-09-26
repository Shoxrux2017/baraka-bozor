<?php

declare(strict_types=1);

namespace App\Modules\Catalog;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/**
 * Catalog search and ordering shared by the Admin and Customer lists.
 *
 * Search matches either name as a substring (`BR-CAT-005`, `DL-17` (10)),
 * ignoring what a person typing on a phone does not control: letter case,
 * `ё` typed as `е` (мед finds Мёд), and the four ways the Uzbek oʻ and gʻ
 * apostrophe arrives (ʻ ‘ ’ `), all read as the plain `'` the catalog is
 * written with (`DL-16`). PostgreSQL folds both the column and the pattern,
 * so Cyrillic case folds the way the database folds it — which is why the
 * database must run a UTF-8 character type (`docs/08` section 1). The term's
 * own `%`, `_` and `\` are escaped, so "50%" looks for "50%".
 *
 * Ordering is `sort_order`, then `name_uz`, then the id, so a page boundary
 * never shuffles two rows with equal sort keys. Columns are qualified with
 * the model's table, so a caller may join without making them ambiguous.
 */
final class CatalogSearch
{
    /** The longest search term accepted. */
    public const MAX_TERM_LENGTH = 100;

    /** Characters folded before comparing, and what each becomes. */
    private const FOLD_FROM = 'ёʻ‘’`';

    private const FOLD_TO = "е''''";

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

        $pattern = '%'.addcslashes($term, '\\%_').'%';
        $uz = $query->qualifyColumn('name_uz');
        $ru = $query->qualifyColumn('name_ru');
        $folded = 'translate(lower(?), ?, ?)';

        return $query->where(static function (Builder $names) use ($pattern, $uz, $ru, $folded): void {
            $names->whereRaw("translate(lower({$uz}), ?, ?) like {$folded}", [
                self::FOLD_FROM, self::FOLD_TO, $pattern, self::FOLD_FROM, self::FOLD_TO,
            ])->orWhereRaw("translate(lower({$ru}), ?, ?) like {$folded}", [
                self::FOLD_FROM, self::FOLD_TO, $pattern, self::FOLD_FROM, self::FOLD_TO,
            ]);
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
