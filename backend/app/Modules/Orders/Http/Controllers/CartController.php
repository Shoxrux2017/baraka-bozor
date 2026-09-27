<?php

declare(strict_types=1);

namespace App\Modules\Orders\Http\Controllers;

use App\Http\Controllers\Controller;
use App\Http\Requests\EmptyBodyRequest;
use App\Models\Cart;
use App\Models\User;
use App\Modules\Orders\Actions\ChangeCart;
use App\Modules\Orders\CartView;
use App\Modules\Orders\CustomerCart;
use App\Modules\Orders\Http\Requests\AddCartItemRequest;
use App\Modules\Orders\Http\Requests\UpdateCartItemRequest;
use App\Modules\Orders\Http\Resources\CartResource;
use App\Modules\Settings\CustomerPriceCalculator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

/**
 * `/customer/cart` (`docs/09` section 17). Every answer is the whole cart, so
 * the client redraws it from one response: `201` for an added line, `200`
 * otherwise, including a removal (`DL-40`).
 */
final class CartController extends Controller
{
    public function show(Request $request): CartResource
    {
        return $this->cart(CustomerCart::of($this->customer($request)));
    }

    public function add(AddCartItemRequest $request, ChangeCart $change): JsonResponse
    {
        /** @var array{product_id: string, quantity: string, customer_note?: string|null, substitution_policy?: string} $fields */
        $fields = $request->validated();

        return $this->cart($change->add($this->customer($request), $fields))->response()->setStatusCode(201);
    }

    public function update(UpdateCartItemRequest $request, string $item, ChangeCart $change): CartResource
    {
        /** @var array{quantity?: string, customer_note?: string|null, substitution_policy?: string} $fields */
        $fields = $request->validated();

        return $this->cart($change->update($this->customer($request), $item, $fields));
    }

    public function remove(EmptyBodyRequest $request, string $item, ChangeCart $change): CartResource
    {
        return $this->cart($change->remove($this->customer($request), $item));
    }

    private function cart(Cart $cart): CartResource
    {
        return new CartResource(CartView::of($cart, CustomerPriceCalculator::current()));
    }

    private function customer(Request $request): User
    {
        $user = $request->user();

        if (! $user instanceof User) {
            abort(401);
        }

        return $user;
    }
}
