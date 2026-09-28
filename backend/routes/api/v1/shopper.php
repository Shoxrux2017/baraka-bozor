<?php

declare(strict_types=1);

use App\Http\Middleware\RequireIdempotencyKey;
use App\Models\Enums\Role;
use App\Modules\Auth\AuthServiceProvider;
use App\Modules\Auth\Http\Middleware\RequireRole;
use App\Modules\Orders\Http\Controllers\ShopperItemController;
use App\Modules\Orders\Http\Controllers\ShopperOrderController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Shopper — docs/09-api-contracts.md Sections 28 to 35
|--------------------------------------------------------------------------
|
| The Shopper's current assignments and the actions on them. Every route
| reaches an order only through the Shopper's own current assignment
| (DL-54 (3)).
|
*/

Route::middleware([AuthServiceProvider::PROTECTED, RequireRole::of(Role::Shopper)])
    ->prefix('shopper')
    ->group(function (): void {
        Route::get('orders', [ShopperOrderController::class, 'index'])->name('shopper.orders.index');
        Route::get('orders/{order}', [ShopperOrderController::class, 'show'])->name('shopper.orders.show');
        Route::post('orders/{order}/accept', [ShopperOrderController::class, 'accept'])->name('shopper.orders.accept');
        Route::post('orders/{order}/start', [ShopperOrderController::class, 'start'])->name('shopper.orders.start');

        // The key is checked after the session and the role (DL-39).
        Route::post('orders/{order}/items/{item}/purchase', [ShopperItemController::class, 'purchase'])
            ->middleware(RequireIdempotencyKey::class)
            ->name('shopper.orders.items.purchase');
        Route::post('orders/{order}/items/{item}/unavailable', [ShopperItemController::class, 'unavailable'])
            ->name('shopper.orders.items.unavailable');
    });
