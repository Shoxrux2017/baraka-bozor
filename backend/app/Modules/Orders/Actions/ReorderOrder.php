<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Models\CartItem;
use App\Models\Enums\ItemRemovedReason;
use App\Models\OrderItem;
use App\Models\User;
use App\Modules\Catalog\CustomerCatalogListing;
use App\Modules\Orders\CustomerCart;
use App\Modules\Orders\CustomerOrders;
use App\Modules\Orders\QuantityPolicy;
use App\Support\Idempotency\IdempotencyStore;
use App\Support\Idempotency\RequestFingerprint;
use App\Support\Scope\ScopedLookup;

/**
 * `POST /customer/orders/{order}/reorder` (`docs/09` section 26, `docs/04`
 * section 33, `BR-HIST-005`, `DL-91` item 3).
 *
 * Copies the lines of one of the Customer's own orders, whatever its status,
 * into the active cart, in line order, with the ordered quantity, note and
 * substitution rule; a line the Customer removed in an edit is not copied. A
 * product the Customer may no longer see, or whose unit changed since, is
 * `unavailable_items`; one already in the cart keeps its line
 * (`skipped_existing_items`); one past the cart's 100 lines is
 * `cart_full_items`. Prices are today's: the cart shows them on every read.
 * It writes only the cart and never creates an order.
 *
 * The answer is stored on the idempotency key, so a replay answers what the
 * first call did even after the cart or the catalog changed. The cart lock is
 * taken before the cart's lines are read, so two reorders never put a product
 * in the cart twice.
 */
final class ReorderOrder
{
    public const OPERATION = 'orders.reorder';

    public function __construct(private readonly IdempotencyStore $idempotency) {}

    /**
     * @return array{added_items: list<array<string, string>>, skipped_existing_items: list<array<string, string>>, unavailable_items: list<array<string, string>>, cart_full_items: list<array<string, string>>}
     */
    public function reorder(User $customer, string $orderId, string $idempotencyKey): array
    {
        return $this->idempotency->runAnswer(
            $customer->id,
            self::OPERATION,
            $idempotencyKey,
            RequestFingerprint::of(self::OPERATION, ['order' => $orderId], []),
            fn (): array => $this->reorderNow($customer, $orderId),
        );
    }

    /**
     * @return array{added_items: list<array<string, string>>, skipped_existing_items: list<array<string, string>>, unavailable_items: list<array<string, string>>, cart_full_items: list<array<string, string>>}
     */
    private function reorderNow(User $customer, string $orderId): array
    {
        $order = ScopedLookup::firstOrNotFound(CustomerOrders::own($customer)->whereKey($orderId));
        $cart = CustomerCart::lock($customer);

        $lines = $order->items()
            ->where(static function ($query): void {
                $query->whereNull('removed_reason_code')
                    ->orWhere('removed_reason_code', '<>', ItemRemovedReason::CustomerRemoved->value);
            })
            ->orderBy('created_at')
            ->orderBy('id')
            ->get();

        $visible = CustomerCatalogListing::visibleProducts()
            ->without('image')
            ->whereIn('products.id', $lines->pluck('product_id')->all())
            ->get()
            ->keyBy('id');

        /** @var array<string, true> $inCart */
        $inCart = $cart->items()->pluck('product_id')->flip()->map(static fn (): bool => true)->all();
        $count = count($inCart);

        $answer = ['added_items' => [], 'skipped_existing_items' => [], 'unavailable_items' => [], 'cart_full_items' => []];

        foreach ($lines as $line) {
            $product = $visible->get($line->product_id);

            if ($product === null || $product->unit_code !== $line->unit_code_snapshot) {
                $answer['unavailable_items'][] = $this->named($line);

                continue;
            }

            if (isset($inCart[$line->product_id])) {
                $answer['skipped_existing_items'][] = $this->named($line);

                continue;
            }

            if ($count >= ChangeCart::MAX_LINES) {
                $answer['cart_full_items'][] = $this->named($line);

                continue;
            }

            $quantityText = QuantityPolicy::format($product->unit_code, $line->ordered_quantity);
            $quantity = QuantityPolicy::parse($product->unit_code, $quantityText);

            $item = new CartItem;
            $item->cart_id = $cart->id;
            $item->forceFill([
                'product_id' => $product->id,
                'quantity' => $quantity->toDecimal(),
                'customer_note' => $line->customer_note_snapshot,
                'substitution_policy' => $line->substitution_policy_snapshot,
            ])->save();

            $inCart[$line->product_id] = true;
            $count++;
            $answer['added_items'][] = $this->named($line) + ['quantity' => $quantityText];
        }

        return $answer;
    }

    /**
     * @return array{product_id: string, name_uz: string, name_ru: string}
     */
    private function named(OrderItem $line): array
    {
        return [
            'product_id' => $line->product_id,
            'name_uz' => $line->product_name_uz_snapshot,
            'name_ru' => $line->product_name_ru_snapshot,
        ];
    }
}
