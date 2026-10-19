<?php

declare(strict_types=1);

namespace App\Modules\Accounts\Http\Controllers;

use App\Exceptions\ApiException;
use App\Http\Controllers\Controller;
use App\Http\Requests\EmptyBodyRequest;
use App\Models\Enums\Role;
use App\Models\Enums\UserStatus;
use App\Models\Order;
use App\Models\User;
use App\Modules\Accounts\Actions\EraseCustomer;
use App\Modules\Accounts\Http\Requests\FindCustomersRequest;
use App\Modules\Accounts\Http\Resources\AdminCustomerResource;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Response;

/**
 * `GET /admin/customers` and `POST /admin/customers/{customer}/erase`
 * (`docs/09` Sections 66 and 67). Admin only; the route group declares it.
 * A Customer who has no app any more calls support and the Admin erases the
 * account with the same action and the same refusals as the Customer's own
 * deletion (`DL-94` item 5).
 */
final class AdminCustomerController extends Controller
{
    public function index(FindCustomersRequest $request): JsonResponse
    {
        $customers = User::query()
            ->where('role', Role::Customer->value)
            ->where('status', '<>', UserStatus::Deleted->value)
            ->where('phone', (string) $request->validated('phone'))
            ->addSelect(['users.*', 'orders_count' => Order::query()
                ->selectRaw('count(*)')
                ->whereColumn('orders.customer_id', 'users.id')])
            ->orderByRaw("case status when 'active' then 0 else 1 end")
            ->orderBy('created_at')
            ->orderBy('id')
            ->get();

        return response()->json([
            'data' => $customers->map(
                static fn (User $customer): array => (new AdminCustomerResource($customer))->resolve($request),
            )->all(),
        ]);
    }

    public function erase(EmptyBodyRequest $request, string $customer, EraseCustomer $erase): Response
    {
        $admin = $request->user();

        if (! $admin instanceof User) {
            abort(401);
        }

        $target = User::query()->find($customer);

        if ($target === null) {
            throw ApiException::notFound();
        }

        $erase->erase($target, $admin);

        return response()->noContent();
    }
}
