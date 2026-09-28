<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Exceptions\ApiException;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Order;
use App\Models\OrderItem;
use App\Models\OrderShopperAssignment;
use App\Models\User;

/**
 * What every Shopper action on a line checks first, under the order lock
 * (`docs/09` sections 30 to 34, `DL-56` (6)): the order is the caller's by a
 * current assignment read under the lock, shopping has started
 * (`409 shopping_not_active`), the line is one the Shopper sees — any other
 * id is the scope-safe `404` — locked after the order (`docs/07` section 16),
 * and it is still `pending` (`409 item_already_resolved`).
 */
final class ShopperLine
{
    /**
     * @return array{Order, OrderShopperAssignment, OrderItem}
     */
    public static function lockPending(User $shopper, string $orderId, string $itemId): array
    {
        [$order, $assignment] = ShopperOrders::lockCurrent($shopper, $orderId);

        if ($order->status !== OrderStatus::Shopping || $assignment->started_at === null) {
            throw ApiException::conflict('shopping_not_active');
        }

        /** @var OrderItem|null $line */
        $line = $order->items()->whereKey($itemId)->lockForUpdate()->first();

        if ($line === null || ! ShopperOrders::sees($line)) {
            throw ApiException::notFound();
        }

        if ($line->status !== OrderItemStatus::Pending) {
            throw ApiException::conflict('item_already_resolved');
        }

        return [$order, $assignment, $line];
    }

    /**
     * The authorized replacement's id, or null when the line has none.
     */
    public static function replacementOf(OrderItem $line): ?string
    {
        return $line->fulfilled_product_id !== null && $line->fulfilled_product_id !== $line->product_id
            ? $line->fulfilled_product_id
            : null;
    }
}
