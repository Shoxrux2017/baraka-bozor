<?php

declare(strict_types=1);

use App\Models\Enums\Role;
use App\Modules\Auth\AuthServiceProvider;
use App\Modules\Auth\Http\Middleware\RequireRole;
use App\Modules\Orders\Http\Controllers\AdminOrderController;
use App\Modules\Orders\Http\Controllers\OperationsApprovalController;
use App\Modules\Orders\Http\Controllers\OperationsCancellationRequestController;
use App\Modules\Orders\Http\Controllers\OperationsOrderController;
use App\Modules\Orders\Http\Controllers\OperationsStaffController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Operations — docs/09-api-contracts.md Sections 38 to 41 and 45
|--------------------------------------------------------------------------
|
| The board of the Operator and the Admin. The first group admits both roles
| and no other; the second, under /admin, the Admin alone (DL-12).
|
*/

Route::middleware([AuthServiceProvider::PROTECTED, RequireRole::of(Role::Operator, Role::Admin)])
    ->prefix('operations')
    ->group(function (): void {
        Route::get('orders', [OperationsOrderController::class, 'index'])->name('operations.orders.index');
        Route::get('orders/{order}', [OperationsOrderController::class, 'show'])->name('operations.orders.show');
        Route::get('summary', [OperationsOrderController::class, 'summary'])->name('operations.summary');
        Route::get('attention', [OperationsOrderController::class, 'attention'])->name('operations.attention');

        Route::get('shoppers', [OperationsStaffController::class, 'shoppers'])->name('operations.shoppers.index');
        Route::post('orders/{order}/shopper-assignment', [OperationsOrderController::class, 'assignShopper'])
            ->name('operations.orders.shopper-assignment.store');
        Route::put('orders/{order}/shopper-assignment', [OperationsOrderController::class, 'reassignShopper'])
            ->name('operations.orders.shopper-assignment.update');

        Route::get('couriers', [OperationsStaffController::class, 'couriers'])->name('operations.couriers.index');
        Route::post('orders/{order}/courier-assignment', [OperationsOrderController::class, 'assignCourier'])
            ->name('operations.orders.courier-assignment.store');
        Route::put('orders/{order}/courier-assignment', [OperationsOrderController::class, 'reassignCourier'])
            ->name('operations.orders.courier-assignment.update');

        Route::post('approvals/{approval}/resolve-expired', [OperationsApprovalController::class, 'resolveExpired'])
            ->name('operations.approvals.resolve-expired');

        Route::get('cancellation-requests', [OperationsCancellationRequestController::class, 'index'])
            ->name('operations.cancellation-requests.index');
        Route::get('cancellation-requests/{request}', [OperationsCancellationRequestController::class, 'show'])
            ->name('operations.cancellation-requests.show');
        Route::post('cancellation-requests/{request}/decision', [OperationsCancellationRequestController::class, 'decide'])
            ->name('operations.cancellation-requests.decision');
        Route::post('orders/{order}/cancel', [OperationsOrderController::class, 'cancel'])
            ->name('operations.orders.cancel');
    });

// The Admin's correction of a price paid, which no Operator makes (docs/02
// section 8, docs/09 section 45).
Route::middleware([AuthServiceProvider::PROTECTED, RequireRole::of(Role::Admin)])
    ->prefix('admin')
    ->group(function (): void {
        Route::post('orders/{order}/items/{item}/price-correction', [AdminOrderController::class, 'correctPrice'])
            ->name('admin.orders.items.price-correction');
    });
