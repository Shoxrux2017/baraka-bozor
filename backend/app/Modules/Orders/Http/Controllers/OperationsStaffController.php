<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Pagination\PaginatedResponse;
use App\Models\Enums\Role;
use App\Models\User;
use App\Modules\Orders\Http\Requests\ListStaffChoicesRequest;
use App\Modules\Orders\Http\Resources\StaffChoiceResource;
use App\Modules\Orders\Operations\StaffPicker;
use Illuminate\Http\JsonResponse;

/**
 * `GET /operations/shoppers` and `GET /operations/couriers` (`docs/09` section
 * 39, `DL-37` (11), `DL-54` (10)): the pickers of the Operator and the Admin,
 * since `/admin/staff` is the Admin's alone (`DL-12`).
 */
final class OperationsStaffController extends Controller
{
    public function shoppers(ListStaffChoicesRequest $request): JsonResponse
    {
        return $this->choices($request, Role::Shopper);
    }

    public function couriers(ListStaffChoicesRequest $request): JsonResponse
    {
        return $this->choices($request, Role::Courier);
    }

    private function choices(ListStaffChoicesRequest $request, Role $role): JsonResponse
    {
        return PaginatedResponse::of(
            StaffPicker::of($role)->paginate($request->perPage(), ['*'], 'page', $request->page()),
            static fn (User $staff): array => (new StaffChoiceResource($staff))->resolve($request),
        );
    }
}
