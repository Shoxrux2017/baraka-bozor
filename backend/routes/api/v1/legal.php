<?php

declare(strict_types=1);

use App\Modules\Legal\Http\Controllers\LegalDocumentController;
use Illuminate\Support\Facades\Route;

/*
|--------------------------------------------------------------------------
| Legal documents, public — docs/09-api-contracts.md Sections 61 and 62
|--------------------------------------------------------------------------
|
| Unauthenticated by design (the app shows them before sign-in, Google Play
| links to them) and throttled. The Admin editor is in settings.php.
|
*/

Route::middleware('throttle:60,1')->prefix('legal')->group(function (): void {
    Route::get('/', [LegalDocumentController::class, 'index'])->name('legal.index');
    Route::get('{kind}', [LegalDocumentController::class, 'show'])
        ->name('legal.show');
});
