<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Models\Enums\ApprovalType;
use App\Models\Order;
use App\Models\User;
use App\Modules\Orders\CustomerQuestions;
use App\Modules\Orders\QuantityPolicy;
use App\Modules\Orders\ShopperLine;
use App\Support\Money\Quantity;
use Illuminate\Support\Facades\DB;
use Illuminate\Validation\ValidationException;

/**
 * `POST /shopper/orders/{order}/items/{item}/reduced-quantity-approval`
 * (`docs/09` section 34, `docs/04` section 16, `BR-QTY-005`, `DL-58`).
 *
 * Asks the Customer to accept a smaller quantity: positive, at the line's
 * unit precision, and below what the Customer would otherwise be billed for —
 * the ordered quantity, or a cap already approved (`422` on
 * `proposed_quantity` otherwise).
 */
final class AskAboutQuantity
{
    public function ask(User $shopper, string $orderId, string $itemId, string $proposedQuantity, ?string $note): Order
    {
        return DB::transaction(function () use ($shopper, $orderId, $itemId, $proposedQuantity, $note): Order {
            [$order, , $line] = ShopperLine::lockPending($shopper, $orderId, $itemId);

            $proposed = QuantityPolicy::parse($line->unit_code_snapshot, $proposedQuantity, 'proposed_quantity');
            $billed = Quantity::fromString($line->approved_quantity_cap ?? $line->ordered_quantity);

            if ($proposed->thousandths >= $billed->thousandths) {
                throw ValidationException::withMessages([
                    'proposed_quantity' => 'A smaller quantity is below the quantity the Customer would be billed for.',
                ]);
            }

            CustomerQuestions::ask($order, $line, $shopper, ApprovalType::ReducedQuantity, [
                'proposed_quantity' => $proposed->toDecimal(),
            ], $note);

            return $order;
        });
    }
}
