<?php

declare(strict_types=1);

use App\Models\Enums\Role;
use App\Modules\Auth\AuthServiceProvider;
use App\Modules\Auth\Http\Middleware\RequireRole;
use App\Modules\Customer\Http\Controllers\AddressController;
use App\Modules\Customer\Http\Controllers\AddressSearchController;
use App\Modules\Customer\Http\Controllers\FavoriteController;
use App\Modules\Customer\Http\Controllers\ProfileController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Customer profile and addresses — docs/09-api-contracts.md Sections 12, 13, 58
|--------------------------------------------------------------------------
|
| A Customer session only; every record is the caller's own.
|
*/

Route::middleware([AuthServiceProvider::PROTECTED, RequireRole::of(Role::Customer)])
    ->prefix('customer')
    ->group(function (): void {
        Route::get('profile', [ProfileController::class, 'show'])->name('customer.profile.show');
        Route::patch('profile', [ProfileController::class, 'update'])->name('customer.profile.update');

        Route::get('addresses', [AddressController::class, 'index'])->name('customer.addresses.index');
        Route::post('addresses', [AddressController::class, 'store'])->name('customer.addresses.store');
        Route::get('addresses/{address}', [AddressController::class, 'show'])->name('customer.addresses.show');
        Route::patch('addresses/{address}', [AddressController::class, 'update'])->name('customer.addresses.update');
        Route::delete('addresses/{address}', [AddressController::class, 'destroy'])->name('customer.addresses.destroy');

        Route::post('address-search', [AddressSearchController::class, 'store'])->name('customer.address-search');

        Route::get('favorites', [FavoriteController::class, 'index'])->name('customer.favorites.index');
        Route::put('favorites/{product}', [FavoriteController::class, 'store'])->name('customer.favorites.store');
        Route::delete('favorites/{product}', [FavoriteController::class, 'destroy'])->name('customer.favorites.destroy');
    });
