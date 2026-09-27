<?php

declare(strict_types=1);

namespace App\Modules\Orders;

use App\Models\Cart;
use App\Models\Enums\CartStatus;
use App\Models\User;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * A Customer's one active cart (`BR-CART-001`), created on first access.
 *
 * The creation is an insert that does nothing when an active cart exists
 * (`carts_customer_active_unique`), so two first accesses at once make one
 * cart. `lock()` then reads it `FOR UPDATE`: every cart change and the order
 * creation take this lock first, so a change lands either before an order is
 * created from the cart or after it, in the new cart (`DL-37` (7)).
 */
final class CustomerCart
{
    public static function of(User $customer): Cart
    {
        self::ensure($customer);

        return self::active($customer)->firstOrFail();
    }

    /**
     * The active cart, locked for the rest of the caller's transaction.
     */
    public static function lock(User $customer): Cart
    {
        self::ensure($customer);

        return self::active($customer)->lockForUpdate()->firstOrFail();
    }

    private static function ensure(User $customer): void
    {
        DB::table('carts')->insertOrIgnore([
            'id' => (string) Str::uuid(),
            'customer_id' => $customer->id,
            'status' => CartStatus::Active->value,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    /**
     * @return Builder<Cart>
     */
    private static function active(User $customer): Builder
    {
        return Cart::query()->where('customer_id', $customer->id)->where('status', CartStatus::Active->value);
    }
}
