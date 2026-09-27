<?php

declare(strict_types=1);

namespace App\Support\Search;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;

/**
 * A substring search over a text column that ignores what a person typing on
 * a phone does not control (`DL-17` (10), `DL-20` (3)): letter case, `ё`
 * typed as `е` (мед finds Мёд), and the four ways the Uzbek oʻ and gʻ
 * apostrophe arrives (ʻ ‘ ’ `), all read as the plain `'`. PostgreSQL folds
 * both the column and the pattern, so Cyrillic case folds the way the
 * database folds it — which is why the database must run a UTF-8 character
 * type (`docs/08` section 1). The term's own `%`, `_` and `\` are escaped, so
 * "50%" looks for "50%".
 */
final class TextSearch
{
    /** The longest search term accepted. */
    public const MAX_TERM_LENGTH = 100;

    /** Characters folded before comparing, and what each becomes. */
    private const FOLD_FROM = 'ёʻ‘’`';

    private const FOLD_TO = "е''''";

    /**
     * Adds "`$column` contains `$term`, folded" to the query, joined by
     * `$boolean`. The column is used as given, so the caller qualifies it.
     *
     * @template TModel of Model
     *
     * @param  Builder<TModel>  $query
     * @param  'and'|'or'  $boolean
     * @return Builder<TModel>
     */
    public static function contains(Builder $query, string $column, string $term, string $boolean = 'and'): Builder
    {
        return $query->whereRaw(
            "translate(lower({$column}), ?, ?) like translate(lower(?), ?, ?)",
            [self::FOLD_FROM, self::FOLD_TO, '%'.addcslashes($term, '\%_').'%', self::FOLD_FROM, self::FOLD_TO],
            $boolean,
        );
    }
}
