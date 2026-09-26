<?php

declare(strict_types=1);

use App\Models\Enums\Role;
use App\Modules\Auth\AuthServiceProvider;
use App\Modules\Auth\Http\Middleware\RequireRole;
use App\Modules\Settings\Http\Controllers\BusinessSettingsController;
use App\Modules\Settings\Http\Controllers\PaymentProviderSettingsController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Business settings — docs/09-api-contracts.md Section 44
|--------------------------------------------------------------------------
|
| Admin only. The Operator surface hides settings (docs/02 Section 7), and
| DL-12 admits the Operator under /operations alone.
|
*/

Route::middleware([AuthServiceProvider::PROTECTED, RequireRole::of(Role::Admin)])
    ->prefix('admin/settings')
    ->group(function (): void {
        Route::get('business', [BusinessSettingsController::class, 'show'])->name('admin.settings.business.show');
        Route::patch('business', [BusinessSettingsController::class, 'update'])->name('admin.settings.business.update');

        Route::get('payment-providers', [PaymentProviderSettingsController::class, 'index'])
            ->name('admin.settings.payment-providers.index');
        Route::patch('payment-providers/{provider}', [PaymentProviderSettingsController::class, 'update'])
            ->name('admin.settings.payment-providers.update');
    });
