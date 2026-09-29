<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Pagination\PaginatedResponse;
use App\Models\OrderCancellationRequest;
use App\Models\User;
use App\Modules\Orders\Actions\DecideCancellationRequest;
use App\Modules\Orders\Http\Requests\DecideCancellationRequestRequest;
use App\Modules\Orders\Http\Requests\ListCancellationRequestsRequest;
use App\Modules\Orders\Http\Resources\BoardOrderResource;
use App\Modules\Orders\Http\Resources\CancellationRequestResource;
use App\Support\Scope\ScopedLookup;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * `GET /operations/cancellation-requests`, `GET .../{request}` and
 * `POST .../{request}/decision` (`docs/09` section 40, `DL-54` (12)). The
 * list is the newest first, narrowed by status; a decision answers the order
 * as the board shows it.
 */
final class OperationsCancellationRequestController extends Controller
{
    private const WITH = ['order', 'requestedBy', 'resolvedBy'];

    public function index(ListCancellationRequestsRequest $request): JsonResponse
    {
        $requests = OrderCancellationRequest::query()->with(self::WITH);
        if ($request->status() !== null) {
            $requests->where('status', $request->status()->value);
        }

        return PaginatedResponse::of(
            $requests->orderByDesc('created_at')->orderByDesc('id')->paginate($request->perPage(), ['*'], 'page', $request->page()),
            static fn (OrderCancellationRequest $cancellation): array => (new CancellationRequestResource($cancellation))->resolve($request),
        );
    }

    public function show(string $request): CancellationRequestResource
    {
        return new CancellationRequestResource(
            ScopedLookup::firstOrNotFound(OrderCancellationRequest::query()->with(self::WITH)->whereKey($request)),
        );
    }

    public function decide(DecideCancellationRequestRequest $decision, string $request, DecideCancellationRequest $decide): BoardOrderResource
    {
        return OperationsOrderController::detail($decide->decide($this->staff($decision), $request, $decision->decision(), $decision->note()));
    }

    private function staff(Request $request): User
    {
        $user = $request->user();

        if (! $user instanceof User) {
            abort(401);
        }

        return $user;
    }
}
