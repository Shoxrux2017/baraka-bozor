<?php

declare(strict_types=1);

use App\Models\Enums\Role;
use App\Modules\Auth\AuthServiceProvider;
use App\Modules\Auth\Http\Middleware\RequireRole;
use App\Modules\Orders\Http\Controllers\CartController;
use App\Modules\Orders\Http\Controllers\CheckoutController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Cart, checkout and orders — docs/09-api-contracts.md Sections 17 to 22
|--------------------------------------------------------------------------
|
| The Customer's own cart; checkout and orders join as their tasks land.
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
    });
