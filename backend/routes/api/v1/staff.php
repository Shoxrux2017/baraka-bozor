<?php

declare(strict_types=1);

use App\Models\Enums\Role;
use App\Modules\Auth\AuthServiceProvider;
use App\Modules\Auth\Http\Middleware\RequireRole;
use App\Modules\Staff\Http\Controllers\AdminStaffController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Staff management — docs/09-api-contracts.md Section 43
|--------------------------------------------------------------------------
|
| Admin only. The first Admin is created by the one-time server command
| (BR-ROLE-009); every other staff account is created here.
|
*/

Route::middleware([AuthServiceProvider::PROTECTED, RequireRole::of(Role::Admin)])
    ->prefix('admin/staff')
    ->group(function (): void {
        Route::get('/', [AdminStaffController::class, 'index'])->name('admin.staff.index');
        Route::post('/', [AdminStaffController::class, 'store'])->name('admin.staff.store');
        Route::get('{user}', [AdminStaffController::class, 'show'])->name('admin.staff.show');
        Route::patch('{user}', [AdminStaffController::class, 'update'])->name('admin.staff.update');
        Route::post('{user}/block', [AdminStaffController::class, 'block'])->name('admin.staff.block');
        Route::post('{user}/activate', [AdminStaffController::class, 'activate'])->name('admin.staff.activate');
        Route::post('{user}/reset-password', [AdminStaffController::class, 'resetPassword'])->name('admin.staff.reset-password');
    });
