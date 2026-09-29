<?php

declare(strict_types=1);

use App\Http\Middleware\RequireIdempotencyKey;
use App\Models\Enums\Role;
use App\Modules\Auth\AuthServiceProvider;
use App\Modules\Auth\Http\Middleware\RequireRole;
use App\Modules\Orders\Http\Controllers\CourierOrderController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Courier — docs/09-api-contracts.md Sections 36 and 37
|--------------------------------------------------------------------------
|
| The Courier's current deliveries and the actions on them. Every route
| reaches an order only through the Courier's own current assignment, but for
| a retry of delivered or not-delivered, which learns the outcome through the
| assignment it ended (DL-54 (3), DL-64 (3)).
|
*/

Route::middleware([AuthServiceProvider::PROTECTED, RequireRole::of(Role::Courier)])
    ->prefix('courier')
    ->group(function (): void {
        Route::get('orders', [CourierOrderController::class, 'index'])->name('courier.orders.index');
        Route::get('orders/{order}', [CourierOrderController::class, 'show'])->name('courier.orders.show');
        Route::post('orders/{order}/accept', [CourierOrderController::class, 'accept'])->name('courier.orders.accept');
        Route::post('orders/{order}/start', [CourierOrderController::class, 'start'])->name('courier.orders.start');
        // The key is checked after the session and the role (DL-39).
        Route::post('orders/{order}/delivered', [CourierOrderController::class, 'delivered'])
            ->middleware(RequireIdempotencyKey::class)
            ->name('courier.orders.delivered');
        Route::post('orders/{order}/not-delivered', [CourierOrderController::class, 'notDelivered'])
            ->name('courier.orders.not-delivered');
    });
