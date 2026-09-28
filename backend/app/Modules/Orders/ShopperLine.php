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
use Illuminate\Validation\ValidationException;

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
     * The product a purchase or a price question is about: the one named,
     * which must be the line's own or its authorized replacement (`422` on
     * `fulfilled_product_id` otherwise), or else the replacement when there is
     * one (`DL-54` (4)).
     */
    public static function productNamed(OrderItem $line, ?string $named): string
    {
        $replacement = self::replacementOf($line);

        if ($named === null) {
            return $replacement ?? $line->product_id;
        }

        $named = strtolower($named);
        if ($named === $line->product_id || $named === $replacement) {
            return $named;
        }

        throw ValidationException::withMessages([
            'fulfilled_product_id' => 'The product bought is the line\'s own or its authorized replacement.',
        ]);
    }

    /**
     * The replacement authorized on the line or bought for it, or null when it
     * has none. A removed line has none: whatever was authorized on it is moot
     * once nothing will be bought (`DL-57` (6)).
     */
    public static function replacementOf(OrderItem $line): ?string
    {
        return $line->status !== OrderItemStatus::Removed
            && $line->fulfilled_product_id !== null
            && $line->fulfilled_product_id !== $line->product_id
            ? $line->fulfilled_product_id
            : null;
    }
}
