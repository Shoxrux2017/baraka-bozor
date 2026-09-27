<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Middleware\RequireIdempotencyKey;
use App\Http\Pagination\PaginatedResponse;
use App\Models\Order;
use App\Models\User;
use App\Modules\Orders\Actions\CreateOrder;
use App\Modules\Orders\CustomerOrders;
use App\Modules\Orders\Http\Requests\CreateOrderRequest;
use App\Modules\Orders\Http\Requests\ListCustomerOrdersRequest;
use App\Modules\Orders\Http\Resources\CustomerOrderResource;
use App\Modules\Orders\Http\Resources\CustomerOrderSummaryResource;
use App\Support\Scope\ScopedLookup;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * `POST /customer/orders`, `GET /customer/orders`, `GET /customer/orders/{order}`
 * (`docs/09` sections 19 and 20). Own orders only; a creation and its replay
 * both answer `201` with the order (`DL-39` (1)).
 */
final class CustomerOrderController extends Controller
{
    public function index(ListCustomerOrdersRequest $request): JsonResponse
    {
        $orders = CustomerOrders::withLineSums(CustomerOrders::own($this->customer($request)))
            ->orderByDesc('created_at')
            ->orderByDesc('order_number')
            ->paginate($request->perPage(), ['*'], 'page', $request->page());

        return PaginatedResponse::of(
            $orders,
            static fn (Order $order): array => (new CustomerOrderSummaryResource($order))->resolve($request),
        );
    }

    public function show(Request $request, string $order): CustomerOrderResource
    {
        return new CustomerOrderResource(ScopedLookup::firstOrNotFound(
            CustomerOrders::own($this->customer($request))->with(['items', 'currentShopperAssignment'])->whereKey($order)
        ));
    }

    public function store(CreateOrderRequest $request, CreateOrder $create): JsonResponse
    {
        $order = $create->create(
            $this->customer($request),
            (string) $request->validated('checkout_token'),
            RequireIdempotencyKey::of($request),
        );

        return (new CustomerOrderResource($order->load(['items', 'currentShopperAssignment'])))
            ->response()
            ->setStatusCode(201);
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
