<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Middleware\RequireIdempotencyKey;
use App\Http\Pagination\PaginatedResponse;
use App\Models\Enums\ItemRemovedReason;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\User;
use App\Modules\Catalog\CatalogSearch;
use App\Modules\Catalog\CustomerCatalogListing;
use App\Modules\Orders\Actions\AskAboutPrice;
use App\Modules\Orders\Actions\AskAboutQuantity;
use App\Modules\Orders\Actions\MarkItemUnavailable;
use App\Modules\Orders\Actions\ProposeSubstitution;
use App\Modules\Orders\Actions\RecordPurchase;
use App\Modules\Orders\Http\Requests\AskAboutPriceRequest;
use App\Modules\Orders\Http\Requests\AskAboutQuantityRequest;
use App\Modules\Orders\Http\Requests\ListReplacementsRequest;
use App\Modules\Orders\Http\Requests\MarkItemUnavailableRequest;
use App\Modules\Orders\Http\Requests\ProposeSubstitutionRequest;
use App\Modules\Orders\Http\Requests\RecordPurchaseRequest;
use App\Modules\Orders\Http\Resources\ReplacementChoiceResource;
use App\Modules\Orders\Http\Resources\ShopperOrderResource;
use App\Modules\Orders\ShopperOrders;
use App\Support\Scope\ScopedLookup;
use Illuminate\Database\Eloquent\Relations\Relation;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * The Shopper's actions on one line (`docs/09` sections 30 to 34): record a
 * purchase, mark the line unavailable, ask the Customer about a price, a
 * replacement or a smaller quantity, and search for a replacement. Each action
 * answers `200` with the order as the Shopper sees it (`docs/09` section 28),
 * a cancelled one included when the line was the last to buy (`DL-54` (3),
 * (7)).
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

    public function priceApproval(AskAboutPriceRequest $request, string $order, string $item, AskAboutPrice $ask): ShopperOrderResource
    {
        $shopper = $this->shopper($request);
        $named = $request->validated('fulfilled_product_id');
        $note = $request->validated('note');

        return $this->resource($shopper, $ask->ask(
            $shopper,
            $order,
            $item,
            (int) $request->validated('actual_market_price_uzs'),
            is_string($named) ? $named : null,
            is_string($note) ? $note : null,
        ));
    }

    public function substitution(ProposeSubstitutionRequest $request, string $order, string $item, ProposeSubstitution $propose): ShopperOrderResource
    {
        $shopper = $this->shopper($request);
        $note = $request->validated('note');

        return $this->resource($shopper, $propose->propose(
            $shopper,
            $order,
            $item,
            (string) $request->validated('replacement_product_id'),
            (int) $request->validated('actual_market_price_uzs'),
            is_string($note) ? $note : null,
        ));
    }

    public function reducedQuantity(AskAboutQuantityRequest $request, string $order, string $item, AskAboutQuantity $ask): ShopperOrderResource
    {
        $shopper = $this->shopper($request);
        $note = $request->validated('note');

        return $this->resource($shopper, $ask->ask(
            $shopper,
            $order,
            $item,
            (string) $request->validated('proposed_quantity'),
            is_string($note) ? $note : null,
        ));
    }

    /**
     * `GET /shopper/orders/{order}/items/{item}/replacements` (`DL-54` (17)):
     * the active products of the line's unit in active categories, other than
     * the original, searched and ordered as the catalog is (`DL-20`), for a
     * line of an order the Shopper holds now.
     */
    public function replacements(ListReplacementsRequest $request, string $order, string $item): JsonResponse
    {
        $held = ScopedLookup::firstOrNotFound(ShopperOrders::current($this->shopper($request))->whereKey($order));
        /** @var OrderItem $line */
        $line = ScopedLookup::firstOrNotFound($held->items()->getQuery()
            ->whereKey($item)
            ->where(static fn ($seen) => $seen
                ->whereNull('removed_reason_code')
                ->orWhere('removed_reason_code', '<>', ItemRemovedReason::CustomerRemoved->value)));

        $products = CatalogSearch::ordered(CatalogSearch::matching(
            CustomerCatalogListing::visibleProducts()
                ->where('products.unit_code', $line->unit_code_snapshot->value)
                ->whereKeyNot($line->product_id),
            $request->search(),
        ))->paginate($request->perPage(), ['*'], 'page', $request->page());

        return PaginatedResponse::of(
            $products,
            static fn (Product $product): array => (new ReplacementChoiceResource($product))->resolve($request),
        );
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
