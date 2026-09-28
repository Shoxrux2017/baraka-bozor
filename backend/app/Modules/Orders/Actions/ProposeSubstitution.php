<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Exceptions\ApiException;
use App\Models\Enums\ApprovalType;
use App\Models\Enums\HistoryActorType;
use App\Models\Enums\OrderHistoryEvent;
use App\Models\Enums\SubstitutionPolicy;
use App\Models\Enums\SubstitutionResolution;
use App\Models\Order;
use App\Models\OrderHistory;
use App\Models\Product;
use App\Models\User;
use App\Modules\Catalog\CustomerCatalogListing;
use App\Modules\Orders\CustomerQuestions;
use App\Modules\Orders\PriceBound;
use App\Modules\Orders\ShopperLine;
use App\Support\Money\MoneyCalculator;
use App\Support\Money\Percentage;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * `POST /shopper/orders/{order}/items/{item}/substitution` (`docs/09`
 * section 33, `docs/04` sections 17 to 19, `BR-PRICE-004`, `BR-PRICE-005`,
 * `DL-54` (5), `DL-58`).
 *
 * The replacement is an active product in an active category, with the line's
 * unit, other than the original (`BR-ITEM-004`): an inactive one is
 * `409 product_unavailable`, another unit `409 replacement_unit_mismatch`,
 * the original `422` on `replacement_product_id`. A line whose rule is
 * `remove_if_unavailable` takes none (`409 substitution_not_allowed`).
 *
 * The Customer's price is the price paid under the line's markup. Under
 * `allow_similar_substitution` and within the automatic ceiling
 * (`BR-PRICE-005`) the replacement is authorized at once and the line stays
 * `pending`, with one `item_substituted` row; otherwise the Customer is asked.
 * A new replacement takes the place of an earlier one and clears the price
 * approved for it, so the Customer's yes to one replacement never authorizes
 * another. The replacement already authorized, proposed again, is a natural
 * repeat.
 */
final class ProposeSubstitution
{
    public function propose(User $shopper, string $orderId, string $itemId, string $replacementId, int $actualMarketPriceUzs, ?string $note): Order
    {
        return DB::transaction(function () use ($shopper, $orderId, $itemId, $replacementId, $actualMarketPriceUzs, $note): Order {
            [$order, , $line] = ShopperLine::lockPending($shopper, $orderId, $itemId);
            $replacementId = strtolower($replacementId);

            if ($line->substitution_policy_snapshot === SubstitutionPolicy::RemoveIfUnavailable) {
                throw ApiException::conflict('substitution_not_allowed');
            }

            if ($replacementId === $line->product_id) {
                throw ValidationException::withMessages(['replacement_product_id' => 'A replacement is another product than the original.']);
            }

            /** @var Product|null $product */
            $product = CustomerCatalogListing::visibleProducts()->whereKey($replacementId)->first();
            if ($product === null) {
                throw ApiException::conflict('product_unavailable', ['product_ids' => [$replacementId]]);
            }

            if ($product->unit_code !== $line->unit_code_snapshot) {
                throw ApiException::conflict('replacement_unit_mismatch');
            }

            $previous = ShopperLine::replacementOf($line);
            if ($previous === $product->id) {
                return $order;
            }

            $proposed = MoneyCalculator::increaseByPercent($actualMarketPriceUzs, Percentage::fromString($line->markup_percent_snapshot));
            $automatic = $line->substitution_policy_snapshot === SubstitutionPolicy::AllowSimilar
                && $proposed <= PriceBound::automatic($line, $order);

            if (! $automatic) {
                CustomerQuestions::ask($order, $line, $shopper, ApprovalType::Substitution, [
                    'proposed_customer_unit_price_uzs' => $proposed,
                    'proposed_actual_market_price_uzs' => $actualMarketPriceUzs,
                    'replacement_product_id' => $product->id,
                    'replacement_name_uz_snapshot' => $product->name_uz,
                    'replacement_name_ru_snapshot' => $product->name_ru,
                    'replacement_unit_code_snapshot' => $line->unit_code_snapshot,
                ], $note);

                return $order;
            }

            $line->forceFill([
                'fulfilled_product_id' => $product->id,
                'fulfilled_product_name_uz_snapshot' => $product->name_uz,
                'fulfilled_product_name_ru_snapshot' => $product->name_ru,
                'fulfilled_unit_code_snapshot' => $line->unit_code_snapshot,
                'substitution_resolution' => SubstitutionResolution::Automatic,
                'approved_replacement_price_uzs' => null,
            ])->save();

            $details = [
                'item_id' => $line->id,
                'product_id' => $product->id,
                'actual_market_price_uzs' => $actualMarketPriceUzs,
                'proposed_customer_unit_price_uzs' => $proposed,
            ];
            if ($previous !== null) {
                $details['previous_product_id'] = $previous;
            }

            $history = new OrderHistory;
            $history->forceFill([
                'order_id' => $order->id,
                'event_type' => OrderHistoryEvent::ItemSubstituted,
                'actor_type' => HistoryActorType::User,
                'actor_user_id' => $shopper->id,
                'note' => $note,
                'details' => $details,
            ])->save();

            return $order;
        });
    }
}
