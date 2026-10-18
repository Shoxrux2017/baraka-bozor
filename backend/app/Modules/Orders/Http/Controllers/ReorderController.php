<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Middleware\RequireIdempotencyKey;
use App\Http\Requests\EmptyBodyRequest;
use App\Models\User;
use App\Modules\Orders\Actions\ReorderOrder;
use Illuminate\Http\JsonResponse;

/**
 * `POST /customer/orders/{order}/reorder` (`docs/09` section 26): the Customer
 * repeats one of their own orders into the cart.
 */
final class ReorderController extends Controller
{
    public function store(EmptyBodyRequest $request, string $order, ReorderOrder $reorder): JsonResponse
    {
        $customer = $request->user();

        if (! $customer instanceof User) {
            abort(401);
        }

        return response()->json(['data' => $reorder->reorder($customer, $order, RequireIdempotencyKey::of($request))]);
    }
}
