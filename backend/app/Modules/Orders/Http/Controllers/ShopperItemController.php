<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Middleware\RequireIdempotencyKey;
use App\Models\Order;
use App\Models\User;
use App\Modules\Orders\Actions\MarkItemUnavailable;
use App\Modules\Orders\Actions\RecordPurchase;
use App\Modules\Orders\Http\Requests\MarkItemUnavailableRequest;
use App\Modules\Orders\Http\Requests\RecordPurchaseRequest;
use App\Modules\Orders\Http\Resources\ShopperOrderResource;
use Illuminate\Database\Eloquent\Relations\Relation;
use Illuminate\Http\Request;

/**
 * The Shopper's actions on one line (`docs/09` sections 30 and 31): record a
 * purchase, mark the line unavailable. Each answers `200` with the order as
 * the Shopper sees it (`docs/09` section 28), a cancelled one included when
 * the line was the last to buy (`DL-54` (3), (7)).
 */
final class ShopperItemController extends Controller
{
    public function purchase(RecordPurchaseRequest $request, string $order, string $item, RecordPurchase $purchase): ShopperOrderResource
    {
        $shopper = $this->shopper($request);
        /** @var array{purchased_quantity: string, actual_market_price_uzs?: int|null, fulfilled_product_id?: string|null} $body */
        $body = $request->validated();

        return $this->resource($shopper, $purchase->purchase($shopper, $order, $item, $body, RequireIdempotencyKey::of($request)));
    }

    public function unavailable(MarkItemUnavailableRequest $request, string $order, string $item, MarkItemUnavailable $unavailable): ShopperOrderResource
    {
        $shopper = $this->shopper($request);
        $note = $request->validated('note');

        return $this->resource($shopper, $unavailable->markUnavailable($shopper, $order, $item, is_string($note) ? $note : null));
    }

    /**
     * The order with the caller's own assignment only (`DL-56` (6)).
     */
    private function resource(User $shopper, Order $order): ShopperOrderResource
    {
        return new ShopperOrderResource($order->load([
            'currentShopperAssignment' => static fn (Relation $assignment) => $assignment->where('shopper_id', $shopper->id),
            'items.fulfilledProduct',
            'items.approvals',
        ]));
    }

    private function shopper(Request $request): User
    {
        $user = $request->user();

        if (! $user instanceof User) {
            abort(401);
        }

        return $user;
    }
}
