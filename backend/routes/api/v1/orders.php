<?php

declare(strict_types=1);

use App\Http\Middleware\RequireIdempotencyKey;
use App\Models\Enums\Role;
use App\Modules\Auth\AuthServiceProvider;
use App\Modules\Auth\Http\Middleware\RequireRole;
use App\Modules\Orders\Http\Controllers\CartController;
use App\Modules\Orders\Http\Controllers\CheckoutController;
use App\Modules\Orders\Http\Controllers\CustomerOrderController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Cart, checkout and orders — docs/09-api-contracts.md Sections 17 to 22
|--------------------------------------------------------------------------
|
| The Customer's own cart, the checkout preview and the Customer's orders.
|
*/

Route::middleware([AuthServiceProvider::PROTECTED, RequireRole::of(Role::Customer)])
    ->prefix('customer')
    ->group(function (): void {
        Route::get('cart', [CartController::class, 'show'])->name('customer.cart.show');
        Route::post('cart/items', [CartController::class, 'add'])->name('customer.cart.items.store');
        Route::patch('cart/items/{item}', [CartController::class, 'update'])->name('customer.cart.items.update');
        Route::delete('cart/items/{item}', [CartController::class, 'remove'])->name('customer.cart.items.destroy');

        Route::post('checkout/preview', [CheckoutController::class, 'preview'])->name('customer.checkout.preview');

        // The key is checked after the session and the role, so a guest is
        // told 401 before a missing key is 400 (DL-39).
        Route::get('orders', [CustomerOrderController::class, 'index'])->name('customer.orders.index');
        Route::post('orders', [CustomerOrderController::class, 'store'])
            ->middleware(RequireIdempotencyKey::class)
            ->name('customer.orders.store');
        Route::get('orders/{order}', [CustomerOrderController::class, 'show'])->name('customer.orders.show');
    });
