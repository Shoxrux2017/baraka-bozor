<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Modules\Orders\Actions\CorrectPrice;
use App\Modules\Orders\Http\Requests\CorrectPriceRequest;
use App\Modules\Orders\Http\Resources\BoardOrderResource;

/**
 * `POST /admin/orders/{order}/items/{item}/price-correction` (`docs/09`
 * section 45): the Admin's alone (`docs/02` section 8), answering the order as
 * the board shows it.
 */
final class AdminOrderController extends Controller
{
    public function correctPrice(CorrectPriceRequest $request, string $order, string $item, CorrectPrice $correct): BoardOrderResource
    {
        $admin = $request->user();
        if (! $admin instanceof User) {
            abort(401);
        }

        return OperationsOrderController::detail($correct->correct(
            $admin,
            $order,
            $item,
            $request->actualMarketPriceUzs(),
            $request->reason(),
        ));
    }
}
