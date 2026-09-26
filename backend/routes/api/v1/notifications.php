<?php

declare(strict_types=1);

use App\Modules\Auth\AuthServiceProvider;
use App\Modules\Notifications\Http\Controllers\PushDeviceController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Push devices — docs/09-api-contracts.md Section 27
|--------------------------------------------------------------------------
|
| Any signed-in account registers its own push token and revokes its own
| devices. Behind the password gate like everything else in the protected
| group: a staff member registers once they have chosen their password.
|
*/

Route::middleware([AuthServiceProvider::PROTECTED])
    ->prefix('push-devices')
    ->group(function (): void {
        Route::post('/', [PushDeviceController::class, 'store'])->name('push-devices.store');
        Route::delete('{device}', [PushDeviceController::class, 'destroy'])->name('push-devices.destroy');
    });
