<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Exceptions\ApiException;
use App\Models\BusinessSettings;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\ItemRemovedReason;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\SubstitutionPolicy;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\OrderItem;
use App\Models\Product;
use App\Models\User;
use App\Modules\Catalog\CustomerCatalogListing;
use App\Modules\Orders\CustomerOrders;
use App\Modules\Orders\OrderPermissions;
use App\Modules\Orders\QuantityPolicy;
use App\Modules\Settings\CustomerPriceCalculator;
use App\Support\Money\MoneyCalculator;
use App\Support\Money\Percentage;
use App\Support\Money\Quantity;
use App\Support\Scope\ScopedLookup;
use Illuminate\Support\Facades\DB;

/**
 * `PUT /customer/orders/{order}/items` (`docs/09` section 21, `docs/04`
 * section 9, `BR-ORDER-004`, `DL-6`, `DL-37` (8), (9), `DL-43`): the Customer
 * sends the whole item list and the delivery wish, while the order is `new`
 * or `shopping_assigned` and the Shopper has not started.
 *
 * Under the order lock the edit is first planned against the lines not
 * removed, and nothing is written until the plan is accepted:
 *
 * - a line that stays keeps its price and markup snapshots and takes the new
 *   quantity, note and rule, its quantity held to the unit it was ordered in;
 * - a product not among them is a new line at the current customer price and
 *   the current markup, if the Customer may still see it;
 * - a line no longer listed becomes `removed` with `customer_removed`, never
 *   deleted.
 *
 * A plan that changes nothing returns the order as it is — a natural repeat,
 * whatever the settings say now. A plan that lowers the merchandise subtotal
 * must still reach the current minimum; one that does not lower it is never
 * refused for it, so a minimum raised after the order was placed does not
 * reach the order (`DL-43` (3)). The fee and markup snapshots of the order
 * stay as at creation; one `edited` history row records what changed.
 */
final class EditOrderItems
{
    public const MAX_LINES = 100;

    /**
     * @param  list<array{product_id: string, quantity: string, customer_note?: string|null, substitution_policy?: string}>  $items
     */
    public function edit(User $customer, string $orderId, array $items, ?string $deliveryTimeNote): Order
    {
        return DB::transaction(function () use ($customer, $orderId, $items, $deliveryTimeNote): Order {
            $order = ScopedLookup::lockOrNotFound(CustomerOrders::own($customer)->whereKey($orderId));
            $order->load('currentShopperAssignment');

            if (! OrderPermissions::canChange($order)) {
                throw ApiException::conflict('order_editing_locked');
            }

            /** @var array<string, OrderItem> $current */
            $current = $order->items()
                ->where('status', '<>', OrderItemStatus::Removed->value)
                ->get()
                ->keyBy('product_id')
                ->all();

            $settings = BusinessSettings::current();
            $prices = new CustomerPriceCalculator(Percentage::fromString($settings->markup_percent));
            $products = $this->productsToAdd(array_values(array_filter(
                $items,
                static fn (array $item): bool => ! isset($current[$item['product_id']])
            )));

            // Plan: nothing is written until the whole list is judged.
            $kept = [];
            $added = [];
            $before = 0;
            $after = 0;

            foreach ($current as $line) {
                $before = MoneyCalculator::sum($before, MoneyCalculator::lineTotal(
                    $line->customer_unit_price_uzs_snapshot,
                    Quantity::fromString($line->ordered_quantity),
                ));
            }

            foreach ($items as $index => $wanted) {
                $note = $wanted['customer_note'] ?? null;
                $policy = SubstitutionPolicy::from($wanted['substitution_policy'] ?? SubstitutionPolicy::AllowSimilar->value);
                $line = $current[$wanted['product_id']] ?? null;

                if ($line !== null) {
                    $quantity = QuantityPolicy::parse($line->unit_code_snapshot, $wanted['quantity'], "items.{$index}.quantity");
                    $kept[] = [$line, $quantity, $note, $policy];
                    $after = MoneyCalculator::sum($after, MoneyCalculator::lineTotal($line->customer_unit_price_uzs_snapshot, $quantity));

                    continue;
                }

                $product = $products[$wanted['product_id']];
                $quantity = QuantityPolicy::parse($product->unit_code, $wanted['quantity'], "items.{$index}.quantity");
                $price = $prices->priceOf($product->market_price_uzs);
                $added[] = [$product, $price, $quantity, $note, $policy];
                $after = MoneyCalculator::sum($after, MoneyCalculator::lineTotal($price, $quantity));
            }

            $wantedProducts = array_column($items, 'product_id');
            $removed = array_values(array_filter(
                $current,
                static fn (OrderItem $line): bool => ! in_array($line->product_id, $wantedProducts, true)
            ));

            $changed = array_values(array_filter(
                $kept,
                static fn (array $plan): bool => $plan[0]->ordered_quantity !== $plan[1]->toDecimal()
                    || $plan[0]->customer_note_snapshot !== $plan[2]
                    || $plan[0]->substitution_policy_snapshot !== $plan[3]
            ));
            $wishChanged = $order->delivery_time_note !== $deliveryTimeNote;

            if ($added === [] && $removed === [] && $changed === [] && ! $wishChanged) {
                return $order;
            }

            $minimum = (int) $settings->minimum_order_uzs;
            if ($after < $before && $after < $minimum) {
                throw ApiException::conflict('minimum_order_not_reached', [
                    'minimum_order_uzs' => $minimum,
                    'shortfall_uzs' => $minimum - $after,
                ]);
            }

            // Apply the plan.
            $details = ['added' => [], 'removed' => [], 'changed' => []];

            foreach ($changed as [$line, $quantity, $note, $policy]) {
                $was = self::terms($line);
                $line->forceFill([
                    'ordered_quantity' => $quantity->toDecimal(),
                    'customer_note_snapshot' => $note,
                    'substitution_policy_snapshot' => $policy,
                ])->save();
                $details['changed'][] = ['order_item_id' => $line->id, 'product_id' => $line->product_id, 'before' => $was, 'after' => self::terms($line)];
            }

            foreach ($added as [$product, $price, $quantity, $note, $policy]) {
                $line = $this->addLine($order, $product, $price, $settings->markup_percent, $quantity, $note, $policy);
                $details['added'][] = [
                    'order_item_id' => $line->id,
                    'product_id' => $product->id,
                    'customer_unit_price_uzs' => $price,
                    'markup_percent' => $settings->markup_percent,
                ] + self::terms($line);
            }

            foreach ($removed as $line) {
                $details['removed'][] = ['order_item_id' => $line->id, 'product_id' => $line->product_id] + self::terms($line);
                $line->forceFill([
                    'status' => OrderItemStatus::Removed,
                    'removed_reason_code' => ItemRemovedReason::CustomerRemoved,
                    'removed_at' => now(),
                    'billable_quantity' => '0.000',
                    'line_total_uzs' => 0,
                ])->save();
            }

            if ($wishChanged) {
                $details['delivery_time_note'] = ['before' => $order->delivery_time_note, 'after' => $deliveryTimeNote];
                $order->delivery_time_note = $deliveryTimeNote;
            }
            $order->updated_at = now();
            $order->save();

            $history = new OrderHistory;
            $history->forceFill([
                'order_id' => $order->id,
                'event_type' => OrderHistoryEvent::Edited,
                'actor_type' => HistoryActorType::User,
                'actor_user_id' => $customer->id,
                'details' => $details,
            ])->save();

            return $order;
        });
    }

    /**
     * The products the edit adds, each visible to the Customer; a product that
     * is not is named in `product_unavailable`, like at checkout.
     *
     * @param  list<array{product_id: string, quantity: string}>  $added
     * @return array<string, Product>
     */
    private function productsToAdd(array $added): array
    {
        $ids = array_column($added, 'product_id');
        if ($ids === []) {
            return [];
        }

        $visible = CustomerCatalogListing::visibleProducts()->without('image')->whereKey($ids)->get()->keyBy('id')->all();
        $missing = array_values(array_diff($ids, array_keys($visible)));

        if ($missing !== []) {
            throw ApiException::conflict('product_unavailable', ['product_ids' => $missing]);
        }

        return $visible;
    }

    private function addLine(Order $order, Product $product, int $price, string $markupPercent, Quantity $quantity, ?string $note, SubstitutionPolicy $policy): OrderItem
    {
        $item = new OrderItem;
        $item->forceFill([
            'order_id' => $order->id,
            'product_id' => $product->id,
            'product_name_uz_snapshot' => $product->name_uz,
            'product_name_ru_snapshot' => $product->name_ru,
            'unit_code_snapshot' => $product->unit_code,
            'price_mode_snapshot' => $product->price_mode,
            'market_price_uzs_snapshot' => $product->market_price_uzs,
            'customer_unit_price_uzs_snapshot' => $price,
            'markup_percent_snapshot' => $markupPercent,
            'ordered_quantity' => $quantity->toDecimal(),
            'billable_quantity' => '0.000',
            'customer_note_snapshot' => $note,
            'substitution_policy_snapshot' => $policy,
            'status' => OrderItemStatus::Pending,
        ])->save();

        return $item;
    }

    /**
     * @return array{quantity: string, customer_note: string|null, substitution_policy: string}
     */
    private static function terms(OrderItem $line): array
    {
        return [
            'quantity' => $line->ordered_quantity,
            'customer_note' => $line->customer_note_snapshot,
            'substitution_policy' => $line->substitution_policy_snapshot->value,
        ];
    }
}
