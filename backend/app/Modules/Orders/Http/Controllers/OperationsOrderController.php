<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Pagination\PaginatedResponse;
use App\Models\Order;
use App\Modules\Orders\Http\Requests\ListBoardOrdersRequest;
use App\Modules\Orders\Http\Resources\BoardOrderResource;
use App\Modules\Orders\Http\Resources\BoardOrderRowResource;
use App\Modules\Orders\Operations\Attention;
use App\Modules\Orders\Operations\BoardSummary;
use App\Modules\Orders\Operations\OrderBoard;
use App\Support\Scope\ScopedLookup;
use Illuminate\Http\JsonResponse;
use Illuminate\Pagination\LengthAwarePaginator;

/**
 * The board of the Operator and the Admin (`docs/09` section 38, `DL-12`):
 * `GET /operations/orders`, `GET /operations/orders/{order}`,
 * `GET /operations/summary`, `GET /operations/attention`. Every order is in
 * scope for both roles; the route admits exactly them.
 */
final class OperationsOrderController extends Controller
{
    public function index(ListBoardOrdersRequest $request): JsonResponse
    {
        $orders = OrderBoard::orders(
            status: $request->status(),
            shopperId: $request->shopperId(),
            paymentMethod: $request->paymentMethod(),
            from: $request->from(),
            to: $request->to(),
            attention: $request->attention(),
            search: $request->search(),
        )->paginate($request->perPage(), ['*'], 'page', $request->page());

        return PaginatedResponse::of(
            $orders,
            static fn (Order $order): array => (new BoardOrderRowResource($order))->resolve($request),
        );
    }

    public function show(string $order): BoardOrderResource
    {
        return new BoardOrderResource(ScopedLookup::firstOrNotFound(
            Order::query()
                ->with(['items', 'history.actor', 'shopperAssignments.shopper', 'shopperAssignments.assignedBy'])
                ->whereKey($order)
        ));
    }

    public function summary(): JsonResponse
    {
        $summary = BoardSummary::at(now());

        return response()->json(['data' => [
            'day' => $summary->day,
            'open_by_status' => $summary->openByStatus,
            'completed_today' => $summary->completedToday,
            'cancelled_today' => $summary->cancelledToday,
            'sales_today_uzs' => $summary->salesTodayUzs,
            'attention_count' => $summary->attentionCount,
        ]]);
    }

    public function attention(): JsonResponse
    {
        $items = Attention::items();
        $count = count($items);

        // The list is as long as the open orders that need attention, so it
        // is answered as one page of the collection envelope (docs/09 §2).
        return PaginatedResponse::of(
            new LengthAwarePaginator($items, $count, max($count, 1), 1),
            static fn (array $item): array => $item,
        );
    }
}
