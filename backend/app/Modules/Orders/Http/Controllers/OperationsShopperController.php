<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Pagination\PaginatedResponse;
use App\Models\User;
use App\Modules\Orders\Http\Requests\ListShoppersRequest;
use App\Modules\Orders\Http\Resources\ShopperChoiceResource;
use App\Modules\Orders\Operations\ShopperPicker;
use Illuminate\Http\JsonResponse;

/**
 * `GET /operations/shoppers` (`docs/09` section 39, `DL-37` (11)): the
 * Shopper picker for the Operator and the Admin, since `/admin/staff` is the
 * Admin's alone (`DL-12`).
 */
final class OperationsShopperController extends Controller
{
    public function index(ListShoppersRequest $request): JsonResponse
    {
        return PaginatedResponse::of(
            ShopperPicker::shoppers()->paginate($request->perPage(), ['*'], 'page', $request->page()),
            static fn (User $shopper): array => (new ShopperChoiceResource($shopper))->resolve($request),
        );
    }
}
