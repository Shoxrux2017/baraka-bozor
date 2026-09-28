<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Middleware\RequireIdempotencyKey;
use App\Http\Pagination\PaginatedResponse;
use App\Http\Requests\EmptyBodyRequest;
use App\Models\Order;
use App\Models\OrderShopperAssignment;
use App\Models\User;
use App\Modules\Orders\Actions\AcceptShoppingAssignment;
use App\Modules\Orders\Actions\CompleteShopping;
use App\Modules\Orders\Actions\StartShopping;
use App\Modules\Orders\Http\Requests\ListShopperOrdersRequest;
use App\Modules\Orders\Http\Resources\ShopperOrderResource;
use App\Modules\Orders\Http\Resources\ShopperOrderSummaryResource;
use App\Modules\Orders\ShopperOrders;
use App\Support\Scope\ScopedLookup;
use Illuminate\Database\Eloquent\Relations\Relation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * `GET /shopper/orders`, `GET /shopper/orders/{order}`, and
 * `POST /shopper/orders/{order}/accept`, `.../start` and `.../complete`
 * (`docs/09` sections 28, 29 and 35). The Shopper's current assignments only
 * (`DL-54` (3)), but for a replay of a completion; the list is the oldest
 * assignment first, the order the Shopper has waited on longest; each action
 * answers `200` with the order.
 */
final class ShopperOrderController extends Controller
{
    public function index(ListShopperOrdersRequest $request): JsonResponse
    {
        $shopper = $this->shopper($request);
        $orders = ShopperOrders::withLineCounts(ShopperOrders::current($shopper))
            ->with(['currentShopperAssignment' => static fn (Relation $assignment) => $assignment->where('shopper_id', $shopper->id)])
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
        $shopper = $this->shopper($request);

        return $this->resource($shopper, ScopedLookup::firstOrNotFound(ShopperOrders::current($shopper)->whereKey($order)));
    }

    public function accept(EmptyBodyRequest $request, string $order, AcceptShoppingAssignment $accept): ShopperOrderResource
    {
        $shopper = $this->shopper($request);

        return $this->resource($shopper, $accept->accept($shopper, $order));
    }

    public function start(EmptyBodyRequest $request, string $order, StartShopping $start): ShopperOrderResource
    {
        $shopper = $this->shopper($request);

        return $this->resource($shopper, $start->start($shopper, $order));
    }

    /**
     * Answers the completed order with the assignment completion ended as the
     * caller's own.
     */
    public function complete(EmptyBodyRequest $request, string $order, CompleteShopping $complete): ShopperOrderResource
    {
        $shopper = $this->shopper($request);
        $completed = $complete->complete($shopper, $order, RequireIdempotencyKey::of($request));

        return new ShopperOrderResource($completed->load(['items.fulfilledProduct', 'items.approvals']));
    }

    /**
     * The order with the caller's own assignment: a reassignment committed
     * between the action and this read leaves the relation empty rather than
     * showing the new Shopper's.
     */
    private function resource(User $shopper, Order $order): ShopperOrderResource
    {
        return new ShopperOrderResource($order->load([
            'currentShopperAssignment' => static fn (Relation $assignment) => $assignment->where('shopper_id', $shopper->id),
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
