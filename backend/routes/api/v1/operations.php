<?php

declare(strict_types=1);

use App\Models\Enums\Role;
use App\Modules\Auth\AuthServiceProvider;
use App\Modules\Auth\Http\Middleware\RequireRole;
use App\Modules\Orders\Http\Controllers\OperationsApprovalController;
use App\Modules\Orders\Http\Controllers\OperationsOrderController;
use App\Modules\Orders\Http\Controllers\OperationsShopperController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Operations — docs/09-api-contracts.md Sections 38 to 41
|--------------------------------------------------------------------------
|
| The board of the Operator and the Admin. Every route here admits both
| roles and no other; admin-only routes live under /admin (DL-12).
|
*/

Route::middleware([AuthServiceProvider::PROTECTED, RequireRole::of(Role::Operator, Role::Admin)])
    ->prefix('operations')
    ->group(function (): void {
        Route::get('orders', [OperationsOrderController::class, 'index'])->name('operations.orders.index');
        Route::get('orders/{order}', [OperationsOrderController::class, 'show'])->name('operations.orders.show');
        Route::get('summary', [OperationsOrderController::class, 'summary'])->name('operations.summary');
        Route::get('attention', [OperationsOrderController::class, 'attention'])->name('operations.attention');

        Route::get('shoppers', [OperationsShopperController::class, 'index'])->name('operations.shoppers.index');
        Route::post('orders/{order}/shopper-assignment', [OperationsOrderController::class, 'assignShopper'])
            ->name('operations.orders.shopper-assignment.store');
        Route::put('orders/{order}/shopper-assignment', [OperationsOrderController::class, 'reassignShopper'])
            ->name('operations.orders.shopper-assignment.update');

        Route::post('approvals/{approval}/resolve-expired', [OperationsApprovalController::class, 'resolveExpired'])
            ->name('operations.approvals.resolve-expired');
    });
