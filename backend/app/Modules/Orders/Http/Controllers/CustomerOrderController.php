<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Middleware\RequireIdempotencyKey;
use App\Http\Pagination\PaginatedResponse;
use App\Models\Order;
use App\Models\User;
use App\Modules\Orders\Actions\CancelOrder;
use App\Modules\Orders\Actions\CreateOrder;
use App\Modules\Orders\Actions\EditOrderItems;
use App\Modules\Orders\CustomerOrders;
use App\Modules\Orders\Http\Requests\CancelOrderRequest;
use App\Modules\Orders\Http\Requests\CreateOrderRequest;
use App\Modules\Orders\Http\Requests\EditOrderItemsRequest;
use App\Modules\Orders\Http\Requests\ListCustomerOrdersRequest;
use App\Modules\Orders\Http\Resources\CustomerOrderResource;
use App\Modules\Orders\Http\Resources\CustomerOrderSummaryResource;
use App\Modules\Orders\OrderLineSums;
use App\Support\Scope\ScopedLookup;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * `POST /customer/orders`, `GET /customer/orders`, `GET /customer/orders/{order}`,
 * `PUT /customer/orders/{order}/items` and `POST /customer/orders/{order}/cancel`
 * (`docs/09` sections 19 to 22). Own orders only; a creation and its replay
 * both answer `201` with the order (`DL-39` (1)); an edit and a cancellation
 * answer `200` with the order.
 */
final class CustomerOrderController extends Controller
{
    public function index(ListCustomerOrdersRequest $request): JsonResponse
    {
        $orders = CustomerOrders::withPendingApprovalCount(OrderLineSums::add(CustomerOrders::own($this->customer($request))))
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
            CustomerOrders::own($this->customer($request))->with(['items', 'currentShopperAssignment', 'approvals', 'livePayment', 'latestCancellationRequest'])->whereKey($order)
        ));
    }

    public function store(CreateOrderRequest $request, CreateOrder $create): JsonResponse
    {
        $order = $create->create(
            $this->customer($request),
            (string) $request->validated('checkout_token'),
            RequireIdempotencyKey::of($request),
        );

        return (new CustomerOrderResource($order->load(['items', 'currentShopperAssignment', 'approvals', 'livePayment', 'latestCancellationRequest'])))
            ->response()
            ->setStatusCode(201);
    }

    public function editItems(EditOrderItemsRequest $request, string $order, EditOrderItems $edit): CustomerOrderResource
    {
        /** @var list<array{product_id: string, quantity: string, customer_note?: string|null, substitution_policy?: string}> $items */
        $items = $request->validated('items');
        $note = $request->validated('delivery_time_note');

        return $this->resource($edit->edit($this->customer($request), $order, $items, is_string($note) ? $note : null));
    }

    public function cancel(CancelOrderRequest $request, string $order, CancelOrder $cancel): CustomerOrderResource
    {
        $reason = $request->validated('reason');

        return $this->resource($cancel->cancel(
            $this->customer($request),
            $order,
            is_string($reason) ? $reason : null,
            RequireIdempotencyKey::of($request),
        ));
    }

    private function resource(Order $order): CustomerOrderResource
    {
        return new CustomerOrderResource($order->load(['items', 'currentShopperAssignment', 'approvals', 'livePayment', 'latestCancellationRequest']));
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
