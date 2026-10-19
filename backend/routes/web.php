<?php

use App\Modules\Legal\Http\Controllers\LegalPageController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Web routes
|--------------------------------------------------------------------------
|
| BarakaBozor serves a Flutter client over the JSON API. The only web pages
| are the public ones for the store listing (`DL-94` item 2): the documents
| and the account-deletion instructions. They need no session and set no
| cookie, so the `web` group's session and cookie middleware is removed.
|
*/

Route::withoutMiddleware('web')
    ->middleware('throttle:60,1')
    ->group(function (): void {
        Route::get('/legal/{kind}', [LegalPageController::class, 'document']);
        Route::get('/account-deletion', [LegalPageController::class, 'accountDeletion']);
    });
