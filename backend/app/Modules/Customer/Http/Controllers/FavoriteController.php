<?php

declare(strict_types=1);

namespace App\Modules\Customer\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Pagination\PaginatedResponse;
use App\Http\Requests\EmptyBodyRequest;
use App\Models\CustomerFavorite;
use App\Models\User;
use App\Modules\Customer\Actions\ChangeFavorites;
use App\Modules\Customer\CustomerFavorites;
use App\Modules\Customer\Http\Requests\ListFavoritesRequest;
use App\Modules\Customer\Http\Resources\FavoriteProductResource;
use App\Modules\Settings\CustomerPriceCalculator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Http\Response;

/**
 * `/customer/favorites` (`docs/09` section 58). Own rows only; a removal
 * answers `204` whatever the product, so it tells nothing about it.
 */
final class FavoriteController extends Controller
{
    public function index(ListFavoritesRequest $request): JsonResponse
    {
        $prices = CustomerPriceCalculator::current();
        $query = CustomerFavorites::own($this->customer($request))
            ->with(['product.image', 'product.category'])
            ->orderByDesc('created_at')
            ->orderByDesc('id');

        return PaginatedResponse::of(
            $query->paginate($request->perPage(), ['*'], 'page', $request->page()),
            static fn (CustomerFavorite $favorite): array => (new FavoriteProductResource($favorite->product, $prices))->resolve($request),
        );
    }

    public function store(EmptyBodyRequest $request, string $product, ChangeFavorites $change): Response
    {
        $change->add($this->customer($request), $product);

        return response()->noContent();
    }

    public function destroy(EmptyBodyRequest $request, string $product, ChangeFavorites $change): Response
    {
        $change->remove($this->customer($request), $product);

        return response()->noContent();
    }

    private function customer(Request $request): User
    {
        $user = $request->user();

        if (! $user instanceof User) {
            abort(401);
        }

        return $user;
    }
}
