<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Exceptions\ApiException;
use App\Models\Enums\ApprovalType;
use App\Models\Enums\PriceMode;
use App\Models\Order;
use App\Models\User;
use App\Modules\Orders\CustomerQuestions;
use App\Modules\Orders\PriceBound;
use App\Modules\Orders\ShopperLine;
use App\Support\Money\MoneyCalculator;
use App\Support\Money\Percentage;
use Illuminate\Support\Facades\DB;

/**
 * `POST /shopper/orders/{order}/items/{item}/price-approval` (`docs/09`
 * section 32, `docs/04` section 14, `DL-54` (5), `DL-58`).
 *
 * Asks the Customer about the price the stall charges for the product the
 * line is to be bought with — the one named, or else its authorized
 * replacement, or the original. Only above that product's bound; at or under
 * it, and always for a fixed original bought as itself, which is billed at
 * its snapshot, it is `409 approval_not_needed`. The proposal carries the
 * price paid and the Customer's price under the line's markup, and names the
 * replacement when it is about one.
 */
final class AskAboutPrice
{
    public function ask(User $shopper, string $orderId, string $itemId, int $actualMarketPriceUzs, ?string $named, ?string $note): Order
    {
        ShopperLine::expireFirst($shopper, $orderId);

        return DB::transaction(function () use ($shopper, $orderId, $itemId, $actualMarketPriceUzs, $named, $note): Order {
            [$order, , $line] = ShopperLine::lockPending($shopper, $orderId, $itemId);
            $product = ShopperLine::productNamed($line, $named);
            $asReplacement = $product !== $line->product_id;

            if (! $asReplacement && $line->price_mode_snapshot === PriceMode::Fixed) {
                throw ApiException::conflict('approval_not_needed');
            }

            $proposed = MoneyCalculator::increaseByPercent($actualMarketPriceUzs, Percentage::fromString($line->markup_percent_snapshot));
            $bound = $asReplacement ? PriceBound::replacement($line, $order) : (int) PriceBound::original($line, $order);

            if ($proposed <= $bound) {
                throw ApiException::conflict('approval_not_needed', ['ceiling_customer_unit_price_uzs' => $bound]);
            }

            CustomerQuestions::ask($order, $line, $shopper, ApprovalType::PriceOverTolerance, [
                'proposed_customer_unit_price_uzs' => $proposed,
                'proposed_actual_market_price_uzs' => $actualMarketPriceUzs,
                'replacement_product_id' => $asReplacement ? $product : null,
                'replacement_name_uz_snapshot' => $asReplacement ? $line->fulfilled_product_name_uz_snapshot : null,
                'replacement_name_ru_snapshot' => $asReplacement ? $line->fulfilled_product_name_ru_snapshot : null,
                'replacement_unit_code_snapshot' => $asReplacement ? $line->fulfilled_unit_code_snapshot : null,
            ], $note);

            return $order;
        });
    }
}
