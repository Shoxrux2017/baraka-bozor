<?php

declare(strict_types=1);

namespace App\Modules\Orders\Actions;

use App\Exceptions\ApiException;
use App\Models\Cart;
use App\Models\CartItem;
use App\Models\Enums\SubstitutionPolicy;
use App\Models\Product;
use App\Models\User;
use App\Modules\Catalog\CustomerCatalogListing;
use App\Modules\Orders\CustomerCart;
use App\Modules\Orders\QuantityPolicy;
use App\Support\Scope\ScopedLookup;
use Illuminate\Support\Facades\DB;

/**
 * Adds, changes and removes lines of a Customer's active cart (`docs/09`
 * section 17, `BR-CART-001` to `BR-CART-004`, `DL-37` (6), (7), (20)).
 *
 * Every change locks the cart first, so it lands before or after an order is
 * created from the cart, never across it. A product is added only while the
 * Customer may see it (`BR-CAT-003`): a hidden product and an id that never
 * existed are the same `409 product_unavailable`, so the answer reveals
 * nothing about a hidden product (`DL-22` (2)). A line whose product has since
 * become unavailable may be removed but not changed.
 */
final class ChangeCart
{
    public const MAX_LINES = 100;

    /**
     * @param  array{product_id: string, quantity: string, customer_note?: string|null, substitution_policy?: string}  $fields
     */
    public function add(User $customer, array $fields): Cart
    {
        return DB::transaction(function () use ($customer, $fields): Cart {
            $cart = CustomerCart::lock($customer);
            $product = $this->visibleProduct($fields['product_id']);
            $quantity = QuantityPolicy::parse($product->unit_code, $fields['quantity']);

            $existing = $cart->items()->where('product_id', $product->id)->first();
            if ($existing !== null) {
                throw ApiException::conflict('cart_item_already_exists', ['cart_item_id' => $existing->id]);
            }

            if ($cart->items()->count() >= self::MAX_LINES) {
                throw ApiException::conflict('cart_full', ['max_lines' => self::MAX_LINES]);
            }

            $item = new CartItem;
            $item->cart_id = $cart->id;
            $item->forceFill([
                'product_id' => $product->id,
                'quantity' => $quantity->toDecimal(),
                'customer_note' => $fields['customer_note'] ?? null,
                'substitution_policy' => $fields['substitution_policy'] ?? SubstitutionPolicy::AllowSimilar->value,
            ])->save();

            return $cart;
        });
    }

    /**
     * @param  array{quantity?: string, customer_note?: string|null, substitution_policy?: string}  $fields
     */
    public function update(User $customer, string $itemId, array $fields): Cart
    {
        return DB::transaction(function () use ($customer, $itemId, $fields): Cart {
            $cart = CustomerCart::lock($customer);
            $item = ScopedLookup::firstOrNotFound(CartItem::query()->where('cart_id', $cart->id)->whereKey($itemId));
            $product = $this->visibleProduct($item->product_id);

            if (array_key_exists('quantity', $fields)) {
                $item->quantity = QuantityPolicy::parse($product->unit_code, $fields['quantity'])->toDecimal();
            }
            if (array_key_exists('customer_note', $fields)) {
                $item->customer_note = $fields['customer_note'];
            }
            if (array_key_exists('substitution_policy', $fields)) {
                $item->substitution_policy = SubstitutionPolicy::from($fields['substitution_policy']);
            }
            $item->save();

            return $cart;
        });
    }

    public function remove(User $customer, string $itemId): Cart
    {
        return DB::transaction(function () use ($customer, $itemId): Cart {
            $cart = CustomerCart::lock($customer);
            ScopedLookup::firstOrNotFound(CartItem::query()->where('cart_id', $cart->id)->whereKey($itemId))->delete();

            return $cart;
        });
    }

    private function visibleProduct(string $productId): Product
    {
        $product = CustomerCatalogListing::visibleProducts()->without('image')->whereKey($productId)->first();

        if ($product === null) {
            throw ApiException::conflict('product_unavailable', ['product_ids' => [$productId]]);
        }

        return $product;
    }
}
