<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Exceptions\ApiException;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\OrderItemStatus;
use App\Models\Enums\OrderStatus;
use App\Models\Enums\PriceMode;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\OrderItem;
use App\Models\OrderItemPriceCorrection;
use App\Models\User;
use App\Modules\Orders\FinalAmounts;
use App\Modules\Orders\PriceBound;
use App\Support\Money\MoneyCalculator;
use App\Support\Money\Percentage;
use App\Support\Money\Quantity;
use App\Support\Scope\ScopedLookup;
use Illuminate\Support\Facades\DB;

/**
 * `POST /admin/orders/{order}/items/{item}/price-correction` (`docs/09`
 * section 45, `docs/02` section 8, `BR-PRICE-006`, `DL-54` (18), `DL-66`).
 *
 * Under the order lock, then the line's (`docs/07` section 16):
 *
 * - an order on the way, completed or cancelled is
 *   `409 price_correction_locked`: once the Courier sets off, a change would
 *   reach the door unseen by the Courier, who carries the amount;
 * - a line not bought, or one billed at its fixed snapshot — a fixed original
 *   bought as itself — is `409 price_correction_not_applicable`: only a price
 *   paid can be mistyped;
 * - the current price again is a natural repeat;
 * - a price whose customer price exceeds the bound of the product bought is
 *   `409 price_correction_above_ceiling`, since a price above it needs the
 *   Customer's decision (`AGENTS.md` section 6).
 *
 * One transaction writes the correction row, the line's new price and total,
 * the final amounts once shopping has completed, and one `price_corrected`
 * history row with the reason (`DL-54` (23)). The order answers as the board
 * shows it.
 */
final class CorrectPrice
{
    /** The states in which the Courier carries the amount or it is settled. */
    private const LOCKED = [OrderStatus::OnTheWay, OrderStatus::Completed, OrderStatus::Cancelled];

    public function correct(User $admin, string $orderId, string $itemId, int $actualMarketPriceUzs, string $reason): Order
    {
        return DB::transaction(function () use ($admin, $orderId, $itemId, $actualMarketPriceUzs, $reason): Order {
            $order = ScopedLookup::lockOrNotFound(Order::query()->whereKey($orderId));
            /** @var OrderItem|null $line */
            $line = $order->items()->whereKey($itemId)->lockForUpdate()->first();
            if ($line === null) {
                throw ApiException::notFound();
            }

            if (in_array($order->status, self::LOCKED, true)) {
                throw ApiException::conflict('price_correction_locked');
            }

            $replacement = $line->fulfilled_product_id !== null && $line->fulfilled_product_id !== $line->product_id;
            if ($line->status !== OrderItemStatus::Purchased || (! $replacement && $line->price_mode_snapshot === PriceMode::Fixed)) {
                throw ApiException::conflict('price_correction_not_applicable');
            }

            if ($line->actual_market_price_uzs === $actualMarketPriceUzs) {
                return $order;
            }

            $billable = MoneyCalculator::increaseByPercent($actualMarketPriceUzs, Percentage::fromString($line->markup_percent_snapshot));
            $bound = $replacement ? PriceBound::replacement($line, $order) : (int) PriceBound::original($line, $order);
            if ($billable > $bound) {
                throw ApiException::conflict('price_correction_above_ceiling', [
                    'ceiling_customer_unit_price_uzs' => $bound,
                    'proposed_customer_unit_price_uzs' => $billable,
                ]);
            }

            $correction = new OrderItemPriceCorrection;
            $correction->forceFill([
                'order_item_id' => $line->id,
                'old_actual_market_price_uzs' => $line->actual_market_price_uzs,
                'new_actual_market_price_uzs' => $actualMarketPriceUzs,
                'old_billable_unit_price_uzs' => $line->billable_unit_price_uzs,
                'new_billable_unit_price_uzs' => $billable,
                'corrected_by_user_id' => $admin->id,
                'reason' => $reason,
            ])->save();

            $line->forceFill([
                'actual_market_price_uzs' => $actualMarketPriceUzs,
                'billable_unit_price_uzs' => $billable,
                'line_total_uzs' => MoneyCalculator::lineTotal($billable, Quantity::fromString($line->billable_quantity)),
            ])->save();

            $details = [
                'item_id' => $line->id,
                'correction_id' => $correction->id,
                'old_actual_market_price_uzs' => $correction->old_actual_market_price_uzs,
                'new_actual_market_price_uzs' => $actualMarketPriceUzs,
                'old_billable_unit_price_uzs' => $correction->old_billable_unit_price_uzs,
                'new_billable_unit_price_uzs' => $billable,
                'line_total_uzs' => $line->line_total_uzs,
            ];
            if ($order->final_total_uzs !== null) {
                FinalAmounts::fill($order);
                $order->save();
                $details['final_total_uzs'] = $order->final_total_uzs;
            }

            $history = new OrderHistory;
            $history->forceFill([
                'order_id' => $order->id,
                'event_type' => OrderHistoryEvent::PriceCorrected,
                'actor_type' => HistoryActorType::User,
                'actor_user_id' => $admin->id,
                'note' => $reason,
                'details' => $details,
            ])->save();

            return $order;
        });
    }
}
