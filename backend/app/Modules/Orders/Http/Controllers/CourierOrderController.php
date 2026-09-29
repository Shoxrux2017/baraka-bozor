<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Middleware\RequireIdempotencyKey;
use App\Http\Pagination\PaginatedResponse;
use App\Http\Requests\EmptyBodyRequest;
use App\Models\Order;
use App\Models\OrderCourierAssignment;
use App\Models\User;
use App\Modules\Orders\Actions\AcceptDelivery;
use App\Modules\Orders\Actions\DeliverOrder;
use App\Modules\Orders\Actions\FailDelivery;
use App\Modules\Orders\Actions\StartDelivery;
use App\Modules\Orders\CourierOrders;
use App\Modules\Orders\Http\Requests\DeliveredRequest;
use App\Modules\Orders\Http\Requests\ListCourierOrdersRequest;
use App\Modules\Orders\Http\Requests\NotDeliveredRequest;
use App\Modules\Orders\Http\Resources\CourierOrderResource;
use App\Support\Scope\ScopedLookup;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * `GET /courier/orders`, `GET /courier/orders/{order}`, and
 * `POST /courier/orders/{order}/accept`, `.../start`, `.../delivered` and
 * `.../not-delivered` (`docs/09` sections 36 and 37). The Courier's current
 * assignments only (`DL-54` (3)), but for a replay of delivered and a repeat
 * of not-delivered; the list is the oldest assignment first, the delivery the
 * Courier has waited on longest; each action answers `200` with the order.
 */
final class CourierOrderController extends Controller
{
    public function index(ListCourierOrdersRequest $request): JsonResponse
    {
        $courier = $this->courier($request);
        $orders = CourierOrders::withDetails(CourierOrders::current($courier), $courier)
            ->orderBy(OrderCourierAssignment::query()
                ->select('assigned_at')
                ->whereColumn('order_courier_assignments.order_id', 'orders.id')
                ->whereNull('ended_at'))
            ->orderBy('order_number')
            ->paginate($request->perPage(), ['*'], 'page', $request->page());

        return PaginatedResponse::of(
            $orders,
            static fn (Order $order): array => (new CourierOrderResource($order))->resolve($request),
        );
    }

    public function show(Request $request, string $order): CourierOrderResource
    {
        $courier = $this->courier($request);

        return new CourierOrderResource(ScopedLookup::firstOrNotFound(
            CourierOrders::withDetails(CourierOrders::current($courier), $courier)->whereKey($order),
        ));
    }

    public function accept(EmptyBodyRequest $request, string $order, AcceptDelivery $accept): CourierOrderResource
    {
        $courier = $this->courier($request);

        return $this->resource($courier, $accept->accept($courier, $order));
    }

    public function start(EmptyBodyRequest $request, string $order, StartDelivery $start): CourierOrderResource
    {
        $courier = $this->courier($request);

        return $this->resource($courier, $start->start($courier, $order));
    }

    public function delivered(DeliveredRequest $request, string $order, DeliverOrder $deliver): CourierOrderResource
    {
        $courier = $this->courier($request);

        return $this->resource($courier, $deliver->deliver($courier, $order, $request->cashReceivedUzs(), RequireIdempotencyKey::of($request)));
    }

    public function notDelivered(NotDeliveredRequest $request, string $order, FailDelivery $fail): CourierOrderResource
    {
        $courier = $this->courier($request);

        return $this->resource($courier, $fail->fail($courier, $order, $request->reason(), $request->note()));
    }

    private function resource(User $courier, Order $order): CourierOrderResource
    {
        return new CourierOrderResource(CourierOrders::loadDetails($order, $courier));
    }

    private function courier(Request $request): User
    {
        $user = $request->user();

        if (! $user instanceof User) {
            abort(401);
        }

        return $user;
    }
}
