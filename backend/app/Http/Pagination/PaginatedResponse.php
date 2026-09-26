<?php

declare(strict_types=1);

namespace App\Http\Pagination;

use Closure;
use Illuminate\Contracts\Pagination\LengthAwarePaginator;
use Illuminate\Http\JsonResponse;

/**
 * The collection envelope of `docs/09-api-contracts.md` section 2:
 * `{"data": [...], "meta": {"pagination": {"page", "per_page", "total",
 * "last_page"}}}`. Laravel's own paginated resource output carries links and
 * a differently shaped `meta`, so every list builds its response here.
 */
final class PaginatedResponse
{
    /**
     * @template TItem
     *
     * @param  LengthAwarePaginator<array-key, TItem>  $page
     * @param  Closure(TItem): array<string, mixed>  $present
     */
    public static function of(LengthAwarePaginator $page, Closure $present): JsonResponse
    {
        $data = [];

        foreach ($page->items() as $item) {
            $data[] = $present($item);
        }

        return new JsonResponse([
            'data' => $data,
            'meta' => ['pagination' => [
                'page' => $page->currentPage(),
                'per_page' => $page->perPage(),
                'total' => $page->total(),
                'last_page' => $page->lastPage(),
            ]],
        ]);
    }
}
