<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Modules\Orders\Actions\ResolveExpiredApproval;
use App\Modules\Orders\Http\Requests\ResolveExpiredApprovalRequest;
use App\Modules\Orders\Http\Resources\BoardOrderResource;

/**
 * `POST /operations/approvals/{approval}/resolve-expired` (`docs/09`
 * section 40): the Operator or the Admin removes the line of an expired
 * approval, and is answered with the order as the board shows it.
 */
final class OperationsApprovalController extends Controller
{
    public function resolveExpired(ResolveExpiredApprovalRequest $request, string $approval, ResolveExpiredApproval $resolve): BoardOrderResource
    {
        $staff = $request->user();
        if (! $staff instanceof User) {
            abort(401);
        }
        $note = $request->validated('note');

        return OperationsOrderController::detail($resolve->resolve($staff, $approval, is_string($note) ? $note : null));
    }
}
