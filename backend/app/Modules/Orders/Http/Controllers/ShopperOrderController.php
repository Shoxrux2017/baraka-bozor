<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Pagination\PaginatedResponse;
use App\Http\Requests\EmptyBodyRequest;
use App\Models\Order;
use App\Models\OrderShopperAssignment;
use App\Models\User;
use App\Modules\Orders\Actions\AcceptShoppingAssignment;
use App\Modules\Orders\Actions\StartShopping;
use App\Modules\Orders\Http\Requests\ListShopperOrdersRequest;
use App\Modules\Orders\Http\Resources\ShopperOrderResource;
use App\Modules\Orders\Http\Resources\ShopperOrderSummaryResource;
use App\Modules\Orders\ShopperOrders;
use App\Support\Scope\ScopedLookup;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * `GET /shopper/orders`, `GET /shopper/orders/{order}`, and
 * `POST /shopper/orders/{order}/accept` and `.../start` (`docs/09` sections
 * 28 and 29). The Shopper's current assignments only (`DL-54` (3)); the list
 * is the oldest assignment first, the order the Shopper has waited on
 * longest; accept and start answer `200` with the order.
 */
final class ShopperOrderController extends Controller
{
    public function index(ListShopperOrdersRequest $request): JsonResponse
    {
        $orders = ShopperOrders::withLineCounts(ShopperOrders::current($this->shopper($request)))
            ->with('currentShopperAssignment')
            ->orderBy(OrderShopperAssignment::query()
                ->select('assigned_at')
                ->whereColumn('order_shopper_assignments.order_id', 'orders.id')
                ->whereNull('ended_at'))
            ->orderBy('order_number')
            ->paginate($request->perPage(), ['*'], 'page', $request->page());

        return PaginatedResponse::of(
            $orders,
            static fn (Order $order): array => (new ShopperOrderSummaryResource($order))->resolve($request),
        );
    }

    public function show(Request $request, string $order): ShopperOrderResource
    {
        return $this->resource(ScopedLookup::firstOrNotFound(
            ShopperOrders::current($this->shopper($request))->whereKey($order)
        ));
    }

    public function accept(EmptyBodyRequest $request, string $order, AcceptShoppingAssignment $accept): ShopperOrderResource
    {
        return $this->resource($accept->accept($this->shopper($request), $order));
    }

    public function start(EmptyBodyRequest $request, string $order, StartShopping $start): ShopperOrderResource
    {
        return $this->resource($start->start($this->shopper($request), $order));
    }

    private function resource(Order $order): ShopperOrderResource
    {
        return new ShopperOrderResource($order->load([
            'currentShopperAssignment',
            'items.fulfilledProduct',
            'items.approvals',
        ]));
    }

    private function shopper(Request $request): User
    {
        $user = $request->user();

        if (! $user instanceof User) {
            abort(401);
        }

        return $user;
    }
}
