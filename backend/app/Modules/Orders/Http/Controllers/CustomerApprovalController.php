<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Middleware\RequireIdempotencyKey;
use App\Http\Pagination\PaginatedResponse;
use App\Models\CustomerApproval;
use App\Models\Enums\ApprovalStatus;
use App\Models\User;
use App\Modules\Orders\Actions\DecideApproval;
use App\Modules\Orders\CustomerApprovals;
use App\Modules\Orders\Http\Requests\DecideApprovalRequest;
use App\Modules\Orders\Http\Requests\ListCustomerApprovalsRequest;
use App\Modules\Orders\Http\Resources\CustomerApprovalResource;
use App\Support\Scope\ScopedLookup;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * `GET /customer/approvals`, `GET /customer/approvals/{approval}` and
 * `POST /customer/approvals/{approval}/decision` (`docs/09` section 23). The
 * Customer's own questions only; the list is the newest first, and its
 * `pending` and `expired` read an approval past its expiry as expired
 * (`DL-54` (8)). A decision answers `200` with the approval as it now stands.
 */
final class CustomerApprovalController extends Controller
{
    public function index(ListCustomerApprovalsRequest $request): JsonResponse
    {
        $approvals = self::withStatus(CustomerApprovals::own($this->customer($request)), $request->status())
            ->with(['order', 'item'])
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->paginate($request->perPage(), ['*'], 'page', $request->page());

        return PaginatedResponse::of(
            $approvals,
            static fn (CustomerApproval $approval): array => (new CustomerApprovalResource($approval))->resolve($request),
        );
    }

    public function show(Request $request, string $approval): CustomerApprovalResource
    {
        return new CustomerApprovalResource(ScopedLookup::firstOrNotFound(
            CustomerApprovals::own($this->customer($request))->with(['order', 'item'])->whereKey($approval)
        ));
    }

    public function decide(DecideApprovalRequest $request, string $approval, DecideApproval $decide): CustomerApprovalResource
    {
        $decided = $decide->decide(
            $this->customer($request),
            $approval,
            (string) $request->validated('decision'),
            RequireIdempotencyKey::of($request),
        );

        return new CustomerApprovalResource($decided->load(['order', 'item']));
    }

    /**
     * Narrows to a status as a read shows it: a pending approval past its
     * expiry is expired, not pending.
     *
     * @param  Builder<CustomerApproval>  $approvals
     * @return Builder<CustomerApproval>
     */
    private static function withStatus(Builder $approvals, ?ApprovalStatus $status): Builder
    {
        return match ($status) {
            null => $approvals,
            ApprovalStatus::Pending => $approvals->where('status', ApprovalStatus::Pending->value)->where('expires_at', '>', now()),
            ApprovalStatus::Expired => $approvals->where(static fn (Builder $expired) => $expired
                ->where('status', ApprovalStatus::Expired->value)
                ->orWhere(static fn (Builder $overdue) => $overdue
                    ->where('status', ApprovalStatus::Pending->value)
                    ->where('expires_at', '<=', now()))),
            default => $approvals->where('status', $status->value),
        };
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
