<?php

declare(strict_types=1);

use App\Modules\Auth\Http\Controllers\ChangePasswordController;
use App\Modules\Auth\Http\Controllers\CurrentUserController;
use App\Modules\Auth\Http\Controllers\CustomerLoginCodeController;
use App\Modules\Auth\Http\Controllers\LogoutController;
use App\Modules\Auth\Http\Controllers\StaffLoginController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Authentication — docs/09-api-contracts.md Sections 6 to 11
|--------------------------------------------------------------------------
|
| Loaded inside the /api/v1 group by the module route loader; no prefix is
| repeated here. The identity, password-change and logout endpoints are
| reachable while the first-login gate is set, so they carry the account
| check but not the `protected` group.
|
*/

Route::prefix('auth')->group(function (): void {
    Route::post('customer/code/request', [CustomerLoginCodeController::class, 'request'])->name('auth.customer.code.request');
    Route::post('customer/code/verify', [CustomerLoginCodeController::class, 'verify'])->name('auth.customer.code.verify');
    Route::post('staff/login', StaffLoginController::class)->name('auth.staff.login');

    Route::middleware(['auth:sanctum', 'account.active'])->group(function (): void {
        Route::get('me', [CurrentUserController::class, 'show'])->name('auth.me.show');
        Route::patch('me', [CurrentUserController::class, 'update'])->name('auth.me.update');
        Route::post('change-password', ChangePasswordController::class)->name('auth.change-password');
        Route::post('logout', LogoutController::class)->name('auth.logout');
    });
});
